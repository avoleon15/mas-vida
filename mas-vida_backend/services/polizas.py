"""Póliza vinculada: gate de beneficios, verificación y retroactividad.

Dos estados de cuenta (arquitectura-cuentas-vivo.md): cuenta base (gratis) y
cuenta con póliza vinculada Y verificada. "pendiente" y "rechazada" cuentan
exactamente igual que no tener póliza: no hay un tercer estado.

Retroactividad al verificar (decidido 19 sep): si la fecha de nacimiento del
registro coincide con la que confirma la aseguradora, todo lo ganado en la
cuenta base se acredita tal cual. Si NO coincide, no hay retroactividad: la
cuenta arranca en cero desde la verificación, y queda constancia en el ledger
(una fila `retroactivo_denegado` por día anulado) en vez de ignorar el
histórico sin dejar rastro. Se cuenta desde la verificación y no desde la
vinculación porque los días intermedios también se calcularon con una edad
sin confirmar, que es justo lo que esta regla evita reprocesar.

Quien se equivoca con su edad no es lo mismo que quien miente (decidido el 4 oct
2026, para el demo; se revisa con casos reales). Una fecha distinta se TOLERA, sin
quitarle nada, si difiere en hasta 2 años de la de la aseguradora (mes y día
incluidos) Y no le da ventaja. Es mentira, y se anula todo lo anterior a la
verificación, si difiere en más de 2 años o si, aunque sea poco, le da ventaja
(ver `es_mentira`).

Lo anulado también deja de contar para la meta semanal y para el desempate de
La Liga y Tus Ligas (ver `cortes_de_retroactivo`).

Las monedas ganadas antes del corte también se anulan (ver
services.monedas.anular_ganadas_antes_de).
"""
from collections import defaultdict
from datetime import date, timedelta

from django.db import IntegrityError, transaction
from django.db.models import Sum, Value
from django.db.models.functions import Lower, Trim
from django.utils import timezone

from Apps.activities.models import ResumenDiario
from Apps.policies.models import PolizaVinculada
from Apps.poincs.models import Ledger
from services import monedas
from services.hearth_rate import calculate_age, fcm
from services.niveles import TOPE_ANUAL
from services.points import AGE_BONUS_MINIMUM

PENDIENTE = "pendiente"
VERIFICADA = "verificada"
RECHAZADA = "rechazada"

# Filas que componen los puntos de un día (incluye el retroactivo anulado,
# para que un día anulado quede en neto 0 y no se vuelva a ajustar).
TIPOS_DEL_DIA = (
    Ledger.TipoLedger.PASOS,
    Ledger.TipoLedger.INTENSIDAD,
    Ledger.TipoLedger.AJUSTE_MANUAL,
    Ledger.TipoLedger.RETROACTIVO_DENEGADO,
)


class PolizaYaVinculada(Exception):
    """El usuario ya tiene una póliza pendiente o verificada."""


class FaltaFechaConfirmada(Exception):
    """No se puede verificar sin la fecha de nacimiento que dio la aseguradora."""


class PolizaEnOtraCuenta(Exception):
    """Esa póliza ya está verificada en otra cuenta: una cuenta verificada por póliza."""


MOTIVO_POLIZA_EN_OTRA_CUENTA = "poliza_en_otra_cuenta"


def _verificada_en_otra_cuenta(poliza: PolizaVinculada) -> bool:
    # Se normaliza en la base y no en Python, para comparar exactamente como la
    # restricción `uq_poliza_verificada_en_una_cuenta` (por ejemplo, SQLite no pasa
    # la Ñ a minúscula y Python sí).
    return (
        PolizaVinculada.objects
        .annotate(aseguradora_norm=Lower(Trim("insurer")), numero_norm=Lower(Trim("policy_number")))
        .filter(
            estado_verificacion=VERIFICADA,
            aseguradora_norm=Lower(Trim(Value(poliza.insurer))),
            numero_norm=Lower(Trim(Value(poliza.policy_number))),
        )
        .exclude(pk=poliza.pk)
        .exists()
    )


def _mismo_dia_otro_anio(fecha: date, anio: int) -> date:
    """La misma fecha en otro año; el 29 de febrero cae en el 28 si no es bisiesto."""
    try:
        return fecha.replace(year=anio)
    except ValueError:
        return fecha.replace(year=anio, day=28)


def proxima_renovacion(fecha_renovacion: date | None, hoy: date | None = None) -> date | None:
    """La próxima renovación anual a partir de la que dio la aseguradora.

    La póliza se renueva cada año en la misma fecha y no vence (2 oct 2026): si
    la fecha guardada ya pasó, la renovación siguiente es un año después, y así
    hasta pasar de hoy. El día de la renovación ya cuenta como renovado y
    responde la del año siguiente, igual que `anio_de`, donde ese día es el
    primero del año de póliza nuevo (4 oct 2026).
    """
    if fecha_renovacion is None:
        return None
    hoy = hoy or timezone.localdate()
    anio = fecha_renovacion.year
    renovacion = fecha_renovacion
    while renovacion <= hoy:
        anio += 1
        renovacion = _mismo_dia_otro_anio(fecha_renovacion, anio)
    return renovacion


def anio_de(usuario, fecha: date) -> tuple[date, date]:
    """Primer y último día (inclusivos) del año de `fecha` para este usuario.

    Con póliza verificada es el año de póliza: de un aniversario de la
    renovación al día antes del siguiente (2 oct 2026). Lo de antes del inicio
    de ese año no cuenta para él: cada año arranca en cero. Sin póliza
    verificada la cuenta base usa el año calendario, solo como referencia (no
    paga nada).
    """
    poliza = PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion=VERIFICADA
    ).first()
    ancla = poliza and (poliza.fecha_renovacion or poliza.policy_start_date)
    if not ancla:
        return date(fecha.year, 1, 1), date(fecha.year, 12, 31)

    inicio = _mismo_dia_otro_anio(ancla, fecha.year)
    if inicio > fecha:
        inicio = _mismo_dia_otro_anio(ancla, fecha.year - 1)
    siguiente = _mismo_dia_otro_anio(ancla, inicio.year + 1)
    return inicio, siguiente - timedelta(days=1)


def tiene_ancla_de_anio(usuario) -> bool:
    """True si el año se cuenta por póliza (verificada y con alguna fecha de ancla)."""
    poliza = PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion=VERIFICADA
    ).first()
    return bool(poliza and (poliza.fecha_renovacion or poliza.policy_start_date))


def puntos_del_anio(usuario, fecha: date) -> int:
    """Lo acreditado en el ledger dentro del año (de póliza) que contiene `fecha`.

    La actividad se limita al techo anual: los días ya asentados se recortaron
    con la ventana vigente en su momento (año calendario si todavía no había
    póliza), así que al pasar al año de póliza la suma podría juntar dos años
    calendario y pasarse de 12.000. El ledger no se toca.
    """
    inicio, fin = anio_de(usuario, fecha)
    del_anio = Ledger.objects.filter(usuario=usuario, fecha__range=(inicio, fin))
    chequeo = Ledger.TipoLedger.CHEQUEO_MEDICO
    actividad = del_anio.exclude(tipo=chequeo).aggregate(total=Sum("puntos"))["total"] or 0
    chequeos = del_anio.filter(tipo=chequeo).aggregate(total=Sum("puntos"))["total"] or 0
    return min(actividad, TOPE_ANUAL) + chequeos


def poliza_de(usuario) -> PolizaVinculada | None:
    return PolizaVinculada.objects.filter(usuario=usuario).first()


def tiene_poliza_verificada(usuario) -> bool:
    """Gate duro de todo lo que implica dinero o premio."""
    return PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion=VERIFICADA
    ).exists()


# Hasta cuántos años de diferencia se tolera un error de fecha (mes y día incluidos).
ANIOS_DE_TOLERANCIA = 2


def _edad(nacimiento: date, fecha: date) -> int:
    return 0 if fecha < nacimiento else calculate_age(nacimiento, fecha)


def le_da_ventaja(declarada: date, confirmada: date, fecha: date) -> bool:
    """Si la fecha que dio la persona le facilita algo frente a la de la aseguradora.

    Se mide con las edades en `fecha` (el día de la verificación). Es ventaja:
    cruzar los 60 años (bono +25), una meta semanal de pasos más baja o una FCmáx más
    baja, que hace más fácil la intensidad. Como la meta y la FCmáx bajan con la edad,
    en la práctica es ventaja ser MÁS VIEJA en años cumplidos, aunque sea uno.
    """
    # Import acá: services.goals importa este módulo.
    from services import goals

    edad_declarada, edad_real = _edad(declarada, fecha), _edad(confirmada, fecha)
    return (
        (edad_declarada >= AGE_BONUS_MINIMUM > edad_real)
        or goals.meta_pasos_para_edad(edad_declarada, 0) < goals.meta_pasos_para_edad(edad_real, 0)
        or fcm(edad_declarada) < fcm(edad_real)
    )


def es_mentira(declarada: date, confirmada: date, fecha: date) -> bool:
    """Si la diferencia entre la fecha del registro y la de la aseguradora cuenta como mentira.

    Mentira si difiere en más de 2 años, o si le da ventaja (aunque difiera poco).
    Una fecha distinta, dentro de los 2 años y sin ventaja, es un error y no se castiga.
    """
    if declarada == confirmada:
        return False
    mas_vieja = _mismo_dia_otro_anio(confirmada, confirmada.year - ANIOS_DE_TOLERANCIA)
    mas_nueva = _mismo_dia_otro_anio(confirmada, confirmada.year + ANIOS_DE_TOLERANCIA)
    if not (mas_vieja <= declarada <= mas_nueva):
        return True
    return le_da_ventaja(declarada, confirmada, fecha)


def _corte_de(poliza: PolizaVinculada, declarada: date) -> date | None:
    if (
        poliza.estado_verificacion != VERIFICADA
        or poliza.birth_date_confirmada is None
        or poliza.fecha_verificacion is None
    ):
        return None
    dia_de_la_verificacion = timezone.localtime(poliza.fecha_verificacion).date()
    if not es_mentira(declarada, poliza.birth_date_confirmada, dia_de_la_verificacion):
        return None
    return dia_de_la_verificacion


def fecha_corte_sin_retroactivo(usuario) -> date | None:
    """Día desde el cual cuentan los puntos, si se denegó el retroactivo.

    None = el histórico cuenta completo (sin póliza, pendiente, rechazada, o
    verificada con fecha de nacimiento coincidente o con un error tolerado).
    """
    poliza = PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion=VERIFICADA
    ).first()
    return None if poliza is None else _corte_de(poliza, usuario.birth_date)


def cortes_de_retroactivo(usuario_pks) -> dict[int, date]:
    """{usuario: día de corte} de los que tienen el retroactivo denegado, entre `usuario_pks`.

    Lo anterior al corte no cuenta para la meta semanal ni para el desempate de las
    ligas (los pasos y workouts de esos días siguen guardados y se ven en Progreso).
    """
    filas = (
        PolizaVinculada.objects
        .filter(usuario__in=list(usuario_pks), estado_verificacion=VERIFICADA, birth_date_confirmada__isnull=False)
        .select_related("usuario")
    )
    cortes = {}
    for poliza in filas:
        corte = _corte_de(poliza, poliza.usuario.birth_date)
        if corte is not None:
            cortes[poliza.usuario_id] = corte
    return cortes


@transaction.atomic
def vincular(usuario, policy_number: str, insurer: str, policy_start_date: date) -> PolizaVinculada:
    """Crea la póliza en estado pendiente. Una rechazada se puede volver a enviar."""
    existente = PolizaVinculada.objects.select_for_update().filter(usuario=usuario).first()
    if existente is not None and existente.estado_verificacion != RECHAZADA:
        raise PolizaYaVinculada(existente.estado_verificacion)

    datos = dict(
        policy_number=policy_number,
        insurer=insurer,
        policy_start_date=policy_start_date,
        birth_date_confirmada=None,
        estado_verificacion=PENDIENTE,
        fecha_verificacion=None,
    )
    if existente is None:
        return PolizaVinculada.objects.create(usuario=usuario, **datos)

    for campo, valor in datos.items():
        setattr(existente, campo, valor)
    existente.save()
    return existente


@transaction.atomic
def verificar(poliza: PolizaVinculada, ahora=None) -> str:
    """Marca la póliza como verificada y aplica la regla de retroactividad.

    Devuelve "aplicado" (la fecha coincide), "tolerado" (difiere poco y sin ventaja:
    se conserva todo), "denegado" (mentira: se anula lo anterior) o "sin_cambios"
    (ya estaba verificada). Lanza PolizaEnOtraCuenta si otra cuenta ya la tiene
    verificada (no cambia nada).
    """
    if poliza.estado_verificacion == VERIFICADA:
        return "sin_cambios"
    if poliza.birth_date_confirmada is None:
        raise FaltaFechaConfirmada()
    if _verificada_en_otra_cuenta(poliza):
        raise PolizaEnOtraCuenta()

    ahora = ahora or timezone.now()
    poliza.estado_verificacion = VERIFICADA
    poliza.fecha_verificacion = ahora
    try:
        # Si dos cuentas la verifican a la vez, la restricción de la base deja pasar a una.
        with transaction.atomic():
            poliza.save()
    except IntegrityError:
        raise PolizaEnOtraCuenta()

    usuario = poliza.usuario
    if poliza.birth_date_confirmada == usuario.birth_date:
        return "aplicado"

    hoy = timezone.localtime(ahora).date()
    if not es_mentira(usuario.birth_date, poliza.birth_date_confirmada, hoy):
        return "tolerado"          # un error dentro de lo tolerable: no se le quita nada

    denegar_retroactivo(usuario, hoy)
    return "denegado"


@transaction.atomic
def rechazar(poliza: PolizaVinculada) -> None:
    """Rechazada = igual que sin póliza. No toca el ledger."""
    if poliza.estado_verificacion == VERIFICADA:
        raise ValueError("Una póliza verificada no se rechaza")
    poliza.estado_verificacion = RECHAZADA
    poliza.fecha_verificacion = None
    poliza.save()


def denegar_retroactivo(usuario, corte: date) -> int:
    """Anula en el ledger los puntos de los días anteriores a `corte`.

    Append-only: una fila negativa por día, nunca se edita lo que ya estaba.
    Idempotente: un día que ya quedó en neto 0 no genera otra fila.
    Devuelve cuántos días se anularon.
    """
    por_fecha = defaultdict(list)
    filas = (
        Ledger.objects
        .filter(usuario=usuario, fecha__lt=corte, tipo__in=TIPOS_DEL_DIA)
        .order_by("fecha", "id")
    )
    for fila in filas:
        por_fecha[fila.fecha].append(fila)

    anulados = 0
    for fecha, del_dia in por_fecha.items():
        neto = sum(f.puntos for f in del_dia)
        if neto == 0:
            continue
        ultima = del_dia[-1]
        Ledger.objects.create(
            usuario=usuario,
            fecha=fecha,
            tipo=Ledger.TipoLedger.RETROACTIVO_DENEGADO,
            puntos=-neto,
            # Se copian para que el historial siga mostrando la actividad del día.
            puntos_pasos=ultima.puntos_pasos,
            puntos_intensidad=ultima.puntos_intensidad,
            tope_diario_aplicado=ultima.tope_diario_aplicado,
            version_regla=ultima.version_regla,
        )
        anulados += 1

    # Las monedas ganadas antes del corte tampoco cuentan.
    monedas.anular_ganadas_antes_de(usuario, corte)

    # El resumen del dashboard debe decir lo mismo que el ledger.
    ResumenDiario.objects.filter(usuario=usuario, fecha__lt=corte).update(puntos_dia=0)
    return anulados
