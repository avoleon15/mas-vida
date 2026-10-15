"""Programador de las corridas del objetivo semanal y de La Liga (hora de Guatemala).

- Martes 00:00 (cierre): se ponen al día todas las semanas que ya pasaron su
  margen de gracia y sigan sin cerrar; fija `cumplido` y paga las monedas. El
  lunes entero queda para que lleguen los datos atrasados del domingo
  (`goals.DIAS_DE_GRACIA`, decidido el 3 oct 2026; antes cerraba el lunes 00:00).
  También cierra La Liga del mes que haya pasado su margen de gracia.
- Martes 12:00 (corrección): actualiza los acumulados de la semana que cerró con
  los datos atrasados, sin cambiar `cumplido` ni pagar.
- Día 2 de cada mes, 00:00 (liga): cierra La Liga del mes anterior (tabla final y
  quién gana qué). El día 1 entero es margen de gracia, como el lunes para la
  semana.
- Día 9 de cada mes, 00:00 (pago_liga): paga el podio del mes cerrado, monedas y
  cupón, para que caigan en la season siguiente (`ligas.DIA_DE_PAGO`).
- Si el día 2 o el 9 es martes no hay corrida aparte: la hace el cierre de esa
  misma hora, que también cierra y paga La Liga.

La lógica está separada del bucle y el reloj se inyecta, así se puede probar
una semana entera en un instante. Todo lo que hace es idempotente: correr de
más nunca paga dos veces.

Las horas se calculan con TIME_ZONE del proyecto (America/Guatemala, sin
horario de verano), sin importar en qué zona esté el servidor.
"""
import logging
from datetime import datetime, time, timedelta

from django.utils import timezone

from services import goals, ligas
from services.tiempo import inicio_semana

logger = logging.getLogger(__name__)

CIERRE = "cierre"
CORRECCION = "correccion"
LIGA = "liga"
PAGO_LIGA = "pago_liga"

# (días después del lunes, hora, qué corrida es), en orden. El cierre espera
# `goals.DIAS_DE_GRACIA` días después del domingo.
CORRIDAS_DE_LA_SEMANA = (
    (goals.DIAS_DE_GRACIA, 0, CIERRE),
    (goals.DIAS_DE_GRACIA, 12, CORRECCION),
)

# Cada cuánto despierta mientras espera: si el reloj salta (suspensión del
# servidor) no se pasa de largo una corrida por mucho.
PASO_MAXIMO_SEGUNDOS = 60

# Si una corrida falla (base de datos caída un momento, por ejemplo) se reintenta.
REINTENTO_SEGUNDOS = 300
MAX_INTENTOS = 12


def proxima_ejecucion(ahora: datetime) -> tuple[datetime, str]:
    """La corrida que sigue, ESTRICTAMENTE después de `ahora`.

    Devuelve (momento con zona, CIERRE | CORRECCION | LIGA | PAGO_LIGA). Nunca hay
    dos corridas a la misma hora: si el cierre o el pago de La Liga coincide con el
    cierre semanal, lo cubre el cierre (que también cierra y paga La Liga).
    """
    zona = timezone.get_current_timezone()
    hoy = timezone.localtime(ahora).date()
    lunes = inicio_semana(hoy)

    candidatas = [
        (datetime.combine(semana + timedelta(days=dias), time(hora), tzinfo=zona), tipo)
        for semana in (lunes, lunes + timedelta(days=7))
        for dias, hora, tipo in CORRIDAS_DE_LA_SEMANA
    ]
    momentos_de_cierre = {momento for momento, tipo in candidatas if tipo == CIERRE}
    mes_anterior = hoy.replace(day=1) - timedelta(days=1)
    for mes in (mes_anterior, hoy):
        if ligas.rango_mes(mes)[0] < ligas.PRIMER_MES:
            continue                # antes de que arranque La Liga no hay nada que cerrar ni pagar
        for dia, tipo in ((ligas.dia_de_cierre(mes), LIGA), (ligas.dia_de_pago(mes), PAGO_LIGA)):
            momento = datetime.combine(dia, time(0), tzinfo=zona)
            if momento not in momentos_de_cierre:
                candidatas.append((momento, tipo))

    return min((c for c in candidatas if c[0] > ahora), key=lambda c: c[0])


def ejecutar(tipo: str, momento: datetime):
    """Hace la corrida `tipo` como si fuera `momento`."""
    hoy = timezone.localtime(momento).date()
    if tipo == CIERRE:
        return {
            "semanas": goals.ponerse_al_dia(hoy),
            "liga": ligas.ponerse_al_dia(hoy),
            "pagos": ligas.pagar_al_dia(hoy),
        }
    if tipo == LIGA:
        return ligas.ponerse_al_dia(hoy)
    if tipo == PAGO_LIGA:
        return ligas.pagar_al_dia(hoy)
    if tipo == CORRECCION:
        lunes_anterior = inicio_semana(hoy) - timedelta(days=7)
        return goals.cerrar_semana(lunes_anterior, hoy, correccion=True)
    raise ValueError(f"Corrida desconocida: {tipo}")


def _dormir_hasta(objetivo: datetime, ahora_fn, dormir_fn) -> None:
    """Espera hasta `objetivo` en pasos cortos; nunca vuelve antes de tiempo."""
    while True:
        restante = (objetivo - ahora_fn()).total_seconds()
        if restante <= 0:
            return
        dormir_fn(min(restante, PASO_MAXIMO_SEGUNDOS))


def _ejecutar_con_reintentos(tipo, momento, ejecutar_fn, dormir_fn, antes_de_ejecutar):
    for intento in range(1, MAX_INTENTOS + 1):
        try:
            antes_de_ejecutar()
            ejecutar_fn(tipo, momento)
            return True
        except Exception:
            logger.exception(
                "Falló la corrida de %s (intento %d de %d)", tipo, intento, MAX_INTENTOS
            )
            if intento < MAX_INTENTOS:
                dormir_fn(REINTENTO_SEGUNDOS)
    logger.error(
        "La corrida de %s no se pudo completar; la siguiente corrida de cierre "
        "pone al día lo que haya quedado pendiente", tipo,
    )
    return False


def correr(
    ahora_fn,
    dormir_fn,
    ejecutar_fn=ejecutar,
    antes_de_ejecutar=lambda: None,
    max_corridas=None,
):
    """Bucle del programador. Con `max_corridas=None` corre para siempre.

    Un error en una corrida nunca lo detiene. `antes_de_ejecutar` sirve para
    cerrar conexiones viejas a la base de datos: tras días de espera, la
    conexión abierta ya no sirve.
    """
    ultima = ahora_fn()
    hechas = 0
    while max_corridas is None or hechas < max_corridas:
        objetivo, tipo = proxima_ejecucion(ultima)
        logger.info("Próxima corrida: %s el %s", tipo, objetivo.isoformat())
        _dormir_hasta(objetivo, ahora_fn, dormir_fn)
        _ejecutar_con_reintentos(tipo, objetivo, ejecutar_fn, dormir_fn, antes_de_ejecutar)
        # Se parte del momento programado y no de "ahora": una corrida nunca se
        # repite, y si el servidor estuvo suspendido, las atrasadas se disparan
        # una tras otra en vez de saltarse.
        ultima = objetivo
        hechas += 1
