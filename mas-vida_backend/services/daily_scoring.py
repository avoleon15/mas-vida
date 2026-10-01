"""Puntaje de un día: recalculado desde lo guardado, asentado como delta.

Cada sync recalcula el día COMPLETO a partir de Muestra / Sesion / MuestraBPM,
no del payload recibido. Así un dato tardío (un reloj de terceros que escribe
a Apple Health horas después) cambia el resultado solo, sin lógica especial.

Precedencia de fuente (reglas-puntaje-vivo.md sección 7): si hay un reloj con
datos ese día gana el reloj, luego el anillo, luego el teléfono; dentro de un
mismo nivel gana el de más pasos. Nunca se suman fuentes, ni para pasos ni
para ritmo cardíaco ni para sesiones.

Ledger append-only: el primer sync de un día escribe dos filas (pasos e
intensidad). Si después el resultado cambia, se agrega UNA fila de
`ajuste_manual` con la diferencia (positiva o negativa). Nunca se edita una
fila. Puede haber varios ajustes el mismo día (la restricción única del
ledger no aplica a `ajuste_manual`); cada uno se calcula contra lo ya
acreditado, así que repetir un sync no duplica nada.
"""
import logging
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

from django.db.models import Sum
from django.utils import timezone

from Apps.activities.models import Muestra, MuestraBPM, ResumenDiario, Sesion
from Apps.policies.models import PolizaVinculada
from Apps.poincs.models import Ledger, VersionRegla
from services.device import filtrar_por_dispositivo, seleccionar_dispositivo_ganador
from services.hearth_rate import calculate_age, calculate_intensity_from_heart_rate
from services.niveles import TOPE_ANUAL, nivel_para
from services.points import apply_daily_points_limit, calculate_daily_step_points
from services.polizas import TIPOS_DEL_DIA, fecha_corte_sin_retroactivo

logger = logging.getLogger(__name__)

TOPE_DIARIO = 200
# Sin umbral confirmado (reglas de puntaje, sección 9): un día por encima de
# esto se acredita igual y solo se deja en el log para revisión.
PASOS_DIA_ATIPICO = 60_000


class SinVersionRegla(Exception):
    pass


@dataclass
class ResultadoDia:
    fecha: date
    pasos_totales: int
    puntos_pasos: int
    puntos_intensidad: int
    puntos_dia: int
    tope_diario_aplicado: bool
    workouts_cantidad: int
    workouts_duracion_total: int
    workouts_fc_promedio: int | None
    workouts_fc_maxima: int | None


@dataclass
class ResultadoAnual:
    acreditado_dia: int
    puntos_ano: int
    tope_anual_aplicado: bool
    nivel: int


def _rango_del_dia(fecha: date):
    zona = timezone.get_current_timezone()
    inicio = datetime.combine(fecha, time.min, tzinfo=zona)
    return inicio, inicio + timedelta(days=1)


def fecha_nacimiento_efectiva(usuario) -> date:
    """La confirmada por la aseguradora manda sobre la autoreportada."""
    poliza = PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion="verificada"
    ).first()
    if poliza and poliza.birth_date_confirmada:
        return poliza.birth_date_confirmada
    return usuario.birth_date


def _dicts(queryset, campos):
    filas = []
    for fila in queryset.values(*campos):
        fila["inicio"] = fila["inicio"].isoformat()
        fila["fin"] = fila["fin"].isoformat()
        filas.append(fila)
    return filas


def calcular_dia(usuario, fecha: date) -> ResultadoDia:
    inicio, fin = _rango_del_dia(fecha)
    dispositivo = ("fuente_bundle", "dispositivo_modelo", "dispositivo_fabricante")

    pasos = _dicts(
        Muestra.objects.filter(usuario=usuario, inicio__gte=inicio, inicio__lt=fin),
        ("inicio", "fin", "cantidad", *dispositivo),
    )
    sesiones = _dicts(
        Sesion.objects.filter(usuario=usuario, inicio__gte=inicio, inicio__lt=fin),
        ("inicio", "fin", "duracion_min", "fc_promedio", "fc_maxima", *dispositivo),
    )
    ritmo = _dicts(
        MuestraBPM.objects.filter(usuario=usuario, inicio__gte=inicio, inicio__lt=fin),
        ("inicio", "fin", "bpm", *dispositivo),
    )

    ganador = seleccionar_dispositivo_ganador(pasos, sesiones, ritmo)
    if ganador is not None:
        pasos = filtrar_por_dispositivo(pasos, ganador)
        sesiones = filtrar_por_dispositivo(sesiones, ganador)
        ritmo = filtrar_por_dispositivo(ritmo, ganador)

    pasos_totales = sum(m["cantidad"] for m in pasos)
    edad = calculate_age(fecha_nacimiento_efectiva(usuario), fecha)

    puntos_pasos = calculate_daily_step_points(pasos_totales, edad)
    puntos_intensidad = calculate_intensity_from_heart_rate(ritmo, sesiones, edad)
    puntos_dia = apply_daily_points_limit(puntos_pasos + puntos_intensidad)

    if pasos_totales > PASOS_DIA_ATIPICO:
        logger.warning(
            "Día atípico para revisión: usuario=%s fecha=%s pasos=%d",
            usuario.pk, fecha, pasos_totales,
        )

    return ResultadoDia(
        fecha=fecha,
        pasos_totales=pasos_totales,
        puntos_pasos=puntos_pasos,
        puntos_intensidad=puntos_intensidad,
        puntos_dia=puntos_dia,
        tope_diario_aplicado=puntos_pasos + puntos_intensidad > TOPE_DIARIO,
        workouts_cantidad=len(sesiones),
        workouts_duracion_total=sum(s["duracion_min"] for s in sesiones),
        workouts_fc_promedio=(
            round(sum(s["fc_promedio"] for s in sesiones) / len(sesiones))
            if sesiones else None
        ),
        workouts_fc_maxima=max((s["fc_maxima"] for s in sesiones), default=None),
    )


def version_regla_vigente(fecha: date) -> VersionRegla:
    version = (
        VersionRegla.objects
        .filter(vigente_desde__lte=fecha)
        .order_by("-vigente_desde")
        .first()
    )
    if version is None:
        raise SinVersionRegla(f"No hay versión de regla vigente al {fecha}")
    return version


def _suma(queryset) -> int:
    return queryset.aggregate(total=Sum("puntos"))["total"] or 0


def asentar(usuario, dia: ResultadoDia) -> ResultadoAnual:
    """Escribe en el ledger lo que falte para que la fecha quede bien acreditada."""
    version = version_regla_vigente(dia.fecha)
    del_dia = Ledger.objects.filter(usuario=usuario, fecha=dia.fecha)

    # Techo anual: se mira lo acreditado en el resto del año, sin este día.
    otros_dias = (
        Ledger.objects
        .filter(usuario=usuario, fecha__year=dia.fecha.year)
        .exclude(fecha=dia.fecha)
        .exclude(tipo=Ledger.TipoLedger.CHEQUEO_MEDICO)
    )
    espacio = max(0, TOPE_ANUAL - _suma(otros_dias))
    a_acreditar = min(dia.puntos_dia, espacio)
    tope_anual = a_acreditar < dia.puntos_dia

    # Retroactivo denegado (fecha de nacimiento no coincide al verificar la
    # póliza): lo anterior al corte no cuenta, ni siquiera si llega tarde.
    corte = fecha_corte_sin_retroactivo(usuario)
    if corte is not None and dia.fecha < corte:
        a_acreditar = 0
        tope_anual = False

    columnas = {
        "puntos_pasos": dia.puntos_pasos,
        "puntos_intensidad": dia.puntos_intensidad,
        "tope_diario_aplicado": dia.tope_diario_aplicado,
        "version_regla": version,
    }

    ya_acreditado = _suma(del_dia.filter(tipo__in=TIPOS_DEL_DIA))
    hay_base = del_dia.filter(
        tipo__in=(Ledger.TipoLedger.PASOS, Ledger.TipoLedger.INTENSIDAD)
    ).exists()

    if not hay_base:
        # Recorte: primero se acredita pasos y lo que sobra va a intensidad.
        de_pasos = min(dia.puntos_pasos, a_acreditar)
        Ledger.objects.create(
            usuario=usuario, fecha=dia.fecha, tipo=Ledger.TipoLedger.PASOS,
            puntos=de_pasos, **columnas,
        )
        Ledger.objects.create(
            usuario=usuario, fecha=dia.fecha, tipo=Ledger.TipoLedger.INTENSIDAD,
            puntos=a_acreditar - de_pasos, **columnas,
        )
    elif a_acreditar != ya_acreditado:
        Ledger.objects.create(
            usuario=usuario, fecha=dia.fecha,
            tipo=Ledger.TipoLedger.AJUSTE_MANUAL,
            puntos=a_acreditar - ya_acreditado, **columnas,
        )

    puntos_ano = _suma(
        Ledger.objects.filter(usuario=usuario, fecha__year=dia.fecha.year)
    )
    return ResultadoAnual(
        acreditado_dia=a_acreditar,
        puntos_ano=puntos_ano,
        tope_anual_aplicado=tope_anual,
        nivel=nivel_para(puntos_ano),
    )


def guardar_resumen(usuario, dia: ResultadoDia) -> None:
    """Tabla materializada: se puede borrar y reconstruir, no es fuente de verdad."""
    hubo_sesion = dia.workouts_cantidad > 0
    ResumenDiario.objects.update_or_create(
        usuario=usuario,
        fecha=dia.fecha,
        defaults={
            "pasos_totales_dia": dia.pasos_totales,
            "workouts_cantidad": dia.workouts_cantidad if hubo_sesion else None,
            "workouts_duracion_total_min": dia.workouts_duracion_total if hubo_sesion else None,
            "workouts_fc_promedio": dia.workouts_fc_promedio,
            "workouts_fc_maxima": dia.workouts_fc_maxima,
            "puntos_dia": dia.puntos_dia,
        },
    )
