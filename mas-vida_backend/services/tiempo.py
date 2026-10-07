"""Fechas de los ciclos: semana (objetivo semanal) y season (13 semanas ISO).

Todo en hora de Guatemala (settings.TIME_ZONE). El teléfono nunca decide en
qué semana cae algo: lo decide el servidor con estas funciones.
"""
from datetime import date, timedelta

from django.utils import timezone


def hoy() -> date:
    return timezone.localdate()


def inicio_semana(fecha: date) -> date:
    """Lunes de la semana de `fecha`."""
    return fecha - timedelta(days=fecha.weekday())


def fin_semana(fecha: date) -> date:
    """Domingo de la semana de `fecha`."""
    return inicio_semana(fecha) + timedelta(days=6)


SEMANAS_POR_SEASON = 13
SEASONS_POR_ANIO = 4


def anio_season(fecha: date) -> int:
    """Año de la season: el año ISO, no el de calendario.

    Los primeros días de enero pueden ser la semana 52 o 53 del año anterior
    (el 3 ene 2027 es la semana 53 de 2026) y el 29 dic 2025 ya es la semana 1
    de 2026. Por eso la season de una fecha se identifica con el año ISO.
    """
    return fecha.isocalendar().year


def numero_season(fecha: date) -> int:
    """Season 1 a 4 según la semana ISO: 1-13, 14-26, 27-39 y 40 en adelante.

    La semana 53 (en los años que la tienen) cae en la season 4, que entonces
    dura 14 semanas.
    """
    semana = fecha.isocalendar().week
    return min((semana - 1) // SEMANAS_POR_SEASON + 1, SEASONS_POR_ANIO)


def rango_season(fecha: date) -> tuple[date, date]:
    """(lunes de inicio, domingo de cierre) de la season de `fecha`.

    Toda season empieza en lunes y termina en domingo, así que nunca parte una
    semana. Las seasons siguen las semanas ISO (la semana 1 es la que contiene
    el 4 de enero), iguales para todos.
    """
    anio = anio_season(fecha)
    numero = numero_season(fecha)
    primera_semana = SEMANAS_POR_SEASON * (numero - 1) + 1
    if numero == SEASONS_POR_ANIO:
        ultima_semana = date(anio, 12, 28).isocalendar().week  # 52 o 53
    else:
        ultima_semana = SEMANAS_POR_SEASON * numero
    return (
        date.fromisocalendar(anio, primera_semana, 1),
        date.fromisocalendar(anio, ultima_semana, 7),
    )


def lunes_de_la_season(fecha: date) -> list[date]:
    """Los lunes de todas las semanas de la season de `fecha` (13, o 14)."""
    inicio, fin = rango_season(fecha)
    lunes = []
    dia = inicio
    while dia <= fin:
        lunes.append(dia)
        dia += timedelta(days=7)
    return lunes


def numero_semana_en_season(fecha: date) -> int:
    """Qué semana de su season es la de `fecha`: 1 a 13 (o 14)."""
    inicio, _ = rango_season(fecha)
    return (inicio_semana(fecha) - inicio).days // 7 + 1
