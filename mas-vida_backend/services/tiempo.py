"""Fechas de los ciclos: semana (objetivo semanal) y season.

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


def numero_season(fecha: date) -> int:
    """Seasons trimestrales en fechas fijas: 1 ene, 1 abr, 1 jul, 1 oct."""
    return (fecha.month - 1) // 3 + 1


def rango_season(fecha: date) -> tuple[date, date]:
    numero = numero_season(fecha)
    primer_mes = 3 * (numero - 1) + 1
    inicio = date(fecha.year, primer_mes, 1)
    siguiente = (
        date(fecha.year + 1, 1, 1) if numero == 4 else date(fecha.year, primer_mes + 3, 1)
    )
    return inicio, siguiente - timedelta(days=1)
