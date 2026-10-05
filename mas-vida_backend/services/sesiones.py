"""Sesiones: el token de cada cuenta vence a los 30 días SIN uso (4 oct 2026).

Reglas:
- Cada uso del token lo renueva: quien abre la app seguido nunca se topa con el
  vencimiento. Se anota el último uso a lo más una vez por hora.
- Un token vencido responde 401 y la app vuelve a la pantalla de inicio de sesión.
- Al iniciar sesión, un token vencido NUNCA se revive: se reemplaza por uno nuevo
  (si alguien se llevó la llave vieja, no le sirve aunque la cuenta vuelva a entrar).
  Uno vigente se entrega igual y se renueva.
- Hay un token por cuenta, compartido por sus dispositivos. Cerrar sesión lo borra,
  así que cierra la sesión en todos.
- Un token sin registro de uso (creado por el admin, por ejemplo) cuenta desde que
  se creó.

La cantidad de días se cambia con `settings.DIAS_DE_VIDA_DEL_TOKEN`.
"""
from datetime import datetime, timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework.authtoken.models import Token

from Apps.users.models import UsoDeToken

DIAS_DE_VIDA = 30
# El último uso se vuelve a escribir como máximo una vez por este tiempo.
RENOVAR_CADA = timedelta(hours=1)


def dias_de_vida() -> int:
    return getattr(settings, "DIAS_DE_VIDA_DEL_TOKEN", DIAS_DE_VIDA)


def ultimo_uso_de(token: Token) -> datetime:
    uso = UsoDeToken.objects.filter(token=token).first()
    return uso.ultimo_uso if uso is not None else token.created


def vencido(token: Token, ahora: datetime | None = None) -> bool:
    ahora = ahora or timezone.now()
    return ahora - ultimo_uso_de(token) > timedelta(days=dias_de_vida())


def registrar_uso(token: Token, ahora: datetime | None = None) -> None:
    """Anota que el token se usó ahora; no escribe si ya se anotó hace menos de una hora."""
    ahora = ahora or timezone.now()
    uso = UsoDeToken.objects.filter(token=token).first()
    if uso is None:
        UsoDeToken.objects.update_or_create(token=token, defaults={"ultimo_uso": ahora})
    elif ahora - uso.ultimo_uso >= RENOVAR_CADA:
        UsoDeToken.objects.filter(pk=uso.pk).update(ultimo_uso=ahora)


def token_para(user, ahora: datetime | None = None) -> Token:
    """El token que se entrega al iniciar sesión o registrarse."""
    ahora = ahora or timezone.now()
    existente = Token.objects.filter(user=user).first()
    if existente is not None and vencido(existente, ahora):
        existente.delete()
    token, _ = Token.objects.get_or_create(user=user)
    # Iniciar sesión es un uso: se renueva de una vez, sin esperar la hora.
    UsoDeToken.objects.update_or_create(token=token, defaults={"ultimo_uso": ahora})
    return token


def cerrar_sesion(user) -> None:
    """Borra el token de la cuenta: cierra la sesión en todos sus dispositivos."""
    Token.objects.filter(user=user).delete()
