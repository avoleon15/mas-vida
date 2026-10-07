"""Consentimiento para compartir los datos con la aseguradora (etapa 14, 6 oct 2026).

La persona acepta una pantalla propia y puede revocarla. El servidor guarda cuándo, qué
versión del texto y si se revocó. Solo quien lo tiene vigente entra al reporte de la
aseguradora (`con_consentimiento_vigente`).

El texto vive en la app; el servidor solo conoce su VERSIÓN. Cuando el texto cambia hay
que subir `VERSION_VIGENTE`: quien aceptó una versión anterior deja de contar como
vigente y la app se lo vuelve a pedir.

Con `settings.CONSENTIMIENTO_OBLIGATORIO` encendido, el sync también lo exige.
"""
from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from Apps.users.models import Consentimiento

# [PENDIENTE] el texto de la pantalla (D11) hay que reescribirlo: promete menos de lo que se
# comparte. Cuando se apruebe el texto nuevo, esta es la versión 1.
VERSION_VIGENTE = "1"


class VersionDesactualizada(Exception):
    """Aceptó un texto que ya no es el vigente."""


def obligatorio() -> bool:
    return bool(getattr(settings, "CONSENTIMIENTO_OBLIGATORIO", False))


def _vigentes(usuario):
    return Consentimiento.objects.filter(
        usuario=usuario, version=VERSION_VIGENTE, revocado_en__isnull=True,
    )


def vigente(usuario) -> bool:
    return _vigentes(usuario).exists()


def estado(usuario) -> dict:
    """Lo que la app necesita para decidir si muestra la pantalla de consentimiento."""
    ultimo = Consentimiento.objects.filter(usuario=usuario).order_by("-aceptado_en", "-id").first()
    return {
        "obligatorio": obligatorio(),
        "version_vigente": VERSION_VIGENTE,
        "aceptado": vigente(usuario),
        "version_aceptada": ultimo.version if ultimo else None,
        "aceptado_en": ultimo.aceptado_en if ultimo else None,
        "revocado_en": ultimo.revocado_en if ultimo else None,
    }


def aceptar(usuario, version, ahora=None) -> bool:
    """Acepta la versión vigente. Devuelve True si se guardó una aceptación nueva.

    Idempotente: si ya la tenía vigente no cambia nada. Una versión que no es la vigente
    se rechaza, para que nadie acepte un texto que ya no es el que ve la app.
    """
    if version != VERSION_VIGENTE:
        raise VersionDesactualizada(VERSION_VIGENTE)
    if vigente(usuario):
        return False
    try:
        with transaction.atomic():
            Consentimiento.objects.create(
                usuario=usuario, version=VERSION_VIGENTE, aceptado_en=ahora or timezone.now(),
            )
    except IntegrityError:            # otro tap llegó primero
        return False
    return True


def revocar(usuario, ahora=None) -> int:
    """Revoca todo consentimiento sin revocar de la persona. Devuelve cuántos cerró."""
    return Consentimiento.objects.filter(usuario=usuario, revocado_en__isnull=True).update(
        revocado_en=ahora or timezone.now(),
    )


def con_consentimiento_vigente(usuarios):
    """Los usuarios (un queryset de Usuario) que tienen el consentimiento vigente.

    Es lo que el reporte a la aseguradora tiene que usar: quien no aceptó, o revocó, o
    aceptó un texto anterior, no sale.
    """
    # Un solo filter(): las dos condiciones valen para la MISMA fila de consentimiento.
    return usuarios.filter(
        consentimiento__version=VERSION_VIGENTE, consentimiento__revocado_en__isnull=True,
    ).distinct()
