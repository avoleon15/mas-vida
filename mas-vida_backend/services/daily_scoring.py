"""Puntaje de un día: recalculado desde lo guardado, asentado como delta.

Cada sync recalcula el día COMPLETO a partir de Muestra / Sesion / MuestraBPM,
no del payload recibido. Así un dato tardío (un reloj de terceros que escribe
a Apple Health horas después) cambia el resultado solo, sin lógica especial.

Elección de fuente (decidido 30 sep, cambia la sección 7 de las reglas de
puntaje): cada métrica elige por separado el dispositivo que más aporta, sin
importar si es reloj, anillo o teléfono, y nunca se suma la misma actividad
dos veces.
- Pasos: en cada bloque (una hora, o varias si una muestra de más de una hora las
  cubre) gana el dispositivo con más pasos; los bloques se suman. Una muestra que
  cruza la medianoche se reparte entre los dos días según el tiempo en cada uno.
- Workouts: un entrenamiento que dos dispositivos registran al mismo tiempo
  cuenta una vez (el más largo); los que no se cruzan cuentan todos. Un
  workout necesita ritmo cardíaco: sin eso el serializer lo descarta.
- Intensidad: cada dispositivo calcula la suya con sus propias sesiones y su
  propio ritmo cardíaco (fallback de bpm incluido); gana el de más puntos.
Así pasos e intensidad pueden venir de dispositivos distintos.

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

from django.db.models import Q, Sum
from django.utils import timezone

from Apps.activities.models import Muestra, MuestraBPM, ResumenDiario, Sesion
from Apps.policies.models import PolizaVinculada
from Apps.poincs.models import Ledger
from services.device import (
    agrupar_por_dispositivo,
    clave_dispositivo,
    pasos_ganadores_por_bloque,
)
from services.hearth_rate import (
    calculate_age,
    calculate_intensity_from_heart_rate,
    minutos_por_zona,
    sesiones_se_traslapan,
)
from services.niveles import TOPE_ANUAL, nivel_para
from services.reglas import SinVersionRegla, version_regla_vigente  # noqa: F401  (SinVersionRegla lo captura la vista)
from services.points import apply_daily_points_limit, calculate_daily_step_points
from services.polizas import (
    TIPOS_DEL_DIA,
    anio_de,
    fecha_corte_sin_retroactivo,
    puntos_del_anio,
)

logger = logging.getLogger(__name__)

TOPE_DIARIO = 200
# Sin umbral confirmado (reglas de puntaje, sección 9): un día por encima de
# esto se acredita igual y solo se deja en el log para revisión.
PASOS_DIA_ATIPICO = 60_000


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
    # {"minutos_ligero", "minutos_moderado", "minutos_intenso"} o None sin ritmo cardíaco.
    ritmo_cardiaco: dict | None = None


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


def _sesiones_sin_traslape(sesiones: list[dict]) -> list[dict]:
    """Los workouts del día, contando una sola vez los que se cruzan en el tiempo.

    Si el reloj y el teléfono registran el mismo entrenamiento, cuenta uno solo
    (el más largo). Dos entrenamientos que no se cruzan cuentan los dos, aunque
    vengan de dispositivos distintos. Con duración igual gana el de mayor
    ritmo máximo y, al final, la clave del dispositivo (resultado estable).
    """
    elegidas: list[dict] = []
    candidatas = sorted(
        sesiones,
        key=lambda s: (
            -s["duracion_min"], -s["fc_maxima"], clave_dispositivo(s), s["inicio"],
        ),
    )
    for sesion in candidatas:
        if not any(sesiones_se_traslapan(sesion, otra) for otra in elegidas):
            elegidas.append(sesion)
    return elegidas


def calcular_dia(usuario, fecha: date) -> ResultadoDia:
    inicio, fin = _rango_del_dia(fecha)
    dispositivo = ("fuente_bundle", "dispositivo_modelo", "dispositivo_fabricante")

    # Pasos: las que empiezan en el día y también las que empezaron antes y siguen
    # dentro (una muestra larga que cruza la medianoche cuenta en los dos días).
    pasos = _dicts(
        Muestra.objects.filter(usuario=usuario).filter(
            Q(inicio__gte=inicio, inicio__lt=fin) | Q(inicio__lt=inicio, fin__gt=inicio),
        ),
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

    pasos = pasos_ganadores_por_bloque(pasos, inicio, fin)

    pasos_totales = sum(m["cantidad"] for m in pasos)
    edad = calculate_age(fecha_nacimiento_efectiva(usuario), fecha)

    puntos_pasos = calculate_daily_step_points(pasos_totales, edad)
    sesiones_por = agrupar_por_dispositivo(sesiones)
    ritmo_por = agrupar_por_dispositivo(ritmo)
    puntos_intensidad = max(
        (
            calculate_intensity_from_heart_rate(
                ritmo_por.get(clave, []), sesiones_por.get(clave, []), edad
            )
            for clave in set(sesiones_por) | set(ritmo_por)
        ),
        default=0,
    )
    puntos_dia_bruto = puntos_pasos + puntos_intensidad
    sesiones = _sesiones_sin_traslape(sesiones)
    puntos_dia = apply_daily_points_limit(puntos_dia_bruto)

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
        tope_diario_aplicado=puntos_dia_bruto > TOPE_DIARIO,
        workouts_cantidad=len(sesiones),
        workouts_duracion_total=sum(s["duracion_min"] for s in sesiones),
        workouts_fc_promedio=(
            round(sum(s["fc_promedio"] for s in sesiones) / len(sesiones))
            if sesiones else None
        ),
        workouts_fc_maxima=max((s["fc_maxima"] for s in sesiones), default=None),
        ritmo_cardiaco=minutos_por_zona(ritmo_por, edad),
    )


def _suma(queryset) -> int:
    return queryset.aggregate(total=Sum("puntos"))["total"] or 0


def asentar(usuario, dia: ResultadoDia) -> ResultadoAnual:
    """Escribe en el ledger lo que falte para que la fecha quede bien acreditada."""
    version = version_regla_vigente(dia.fecha)
    del_dia = Ledger.objects.filter(usuario=usuario, fecha=dia.fecha)

    # Techo anual: se mira lo acreditado en el resto del año (de póliza) de
    # este día, sin este día.
    otros_dias = (
        Ledger.objects
        .filter(usuario=usuario, fecha__range=anio_de(usuario, dia.fecha))
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

    # Lo que se reporta es el año en curso: un dato atrasado del año anterior
    # no debe mostrar el total ni el nivel de aquel año.
    puntos_ano = puntos_del_anio(usuario, timezone.localdate())
    return ResultadoAnual(
        acreditado_dia=a_acreditar,
        puntos_ano=puntos_ano,
        tope_anual_aplicado=tope_anual,
        nivel=nivel_para(puntos_ano),
    )


def guardar_resumen(usuario, dia: ResultadoDia) -> None:
    """Tabla materializada: se puede borrar y reconstruir, no es fuente de verdad."""
    hubo_sesion = dia.workouts_cantidad > 0
    # Un día anulado por retroactivo denegado se ve en 0, igual que en el ledger.
    corte = fecha_corte_sin_retroactivo(usuario)
    anulado = corte is not None and dia.fecha < corte
    ResumenDiario.objects.update_or_create(
        usuario=usuario,
        fecha=dia.fecha,
        defaults={
            "pasos_totales_dia": dia.pasos_totales,
            "workouts_cantidad": dia.workouts_cantidad if hubo_sesion else None,
            "workouts_duracion_total_min": dia.workouts_duracion_total if hubo_sesion else None,
            "workouts_fc_promedio": dia.workouts_fc_promedio,
            "workouts_fc_maxima": dia.workouts_fc_maxima,
            "puntos_dia": 0 if anulado else dia.puntos_dia,
            **{
                zona: (dia.ritmo_cardiaco or {}).get(zona)
                for zona in ("minutos_ligero", "minutos_moderado", "minutos_intenso")
            },
        },
    )
