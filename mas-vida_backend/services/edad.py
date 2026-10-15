"""La edad de quien abre una cuenta (6 oct 2026).

La app es solo para mayores de 18 años: aceptar los términos y el consentimiento
de datos de salud es un contrato, y un menor no lo firma solo. El tope de 120 años
evita fechas absurdas (1850, 0001-01-01) que dejaban la FCmáx en un número sin
sentido o hacían fallar el cálculo de puntos.

La edad se cuenta con el día de Guatemala (`settings.TIME_ZONE`), igual que el
resto de las fechas del negocio.
"""
from datetime import date

from django.utils import timezone

EDAD_MINIMA = 18
EDAD_MAXIMA = 120

MENSAJE_FUTURA = "La fecha de nacimiento no puede ser futura."
# El mismo texto que ya muestra la app (lib/validaciones_acceso.dart).
MENSAJE_MENOR = f"Necesitas tener {EDAD_MINIMA} años o más para abrir tu cuenta."
MENSAJE_INVALIDA = "La fecha de nacimiento no es válida."


def edad_en(nacimiento: date, hoy: date) -> int:
    """Años cumplidos en `hoy`. Quien nació un 29 de febrero cumple el 1 de marzo."""
    return hoy.year - nacimiento.year - (
        (hoy.month, hoy.day) < (nacimiento.month, nacimiento.day)
    )


def problema_con_la_fecha_de_nacimiento(nacimiento: date, hoy: date | None = None) -> str | None:
    """Por qué esta fecha de nacimiento no sirve para una cuenta, o None si sirve.

    Primero va la fecha futura: `edad_en` daría un número negativo.
    """
    hoy = hoy or timezone.localdate()
    if nacimiento > hoy:
        return MENSAJE_FUTURA
    edad = edad_en(nacimiento, hoy)
    if edad < EDAD_MINIMA:
        return MENSAJE_MENOR
    if edad > EDAD_MAXIMA:
        return MENSAJE_INVALIDA
    return None
