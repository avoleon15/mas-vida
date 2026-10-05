"""Sesiones con django-rest-knox (decidido el 4 oct 2026; antes, un token de DRF por cuenta).

Reglas:
- Cada inicio de sesión (login o registro) crea un token propio: cada teléfono
  tiene el suyo y se puede cerrar la sesión en uno sin tocar los demás.
- El token vence a los 30 días SIN uso y cada uso lo renueva, pero nunca pasa de
  90 días desde que se inició la sesión: aunque se use a diario, a los 90 días hay
  que volver a entrar. Vencido responde 401 y la app vuelve al inicio de sesión.
- En la base solo queda un hash del token (como con las contraseñas): quien vea
  la base no puede usar los tokens. La clave completa se entrega una sola vez.
- Una cuenta tiene como mucho MAXIMO_DE_SESIONES abiertas; al entrar se cierran las
  que llevan más tiempo sin usarse, nunca la recién abierta. No se usa
  TOKEN_LIMIT_PER_USER de Knox porque con el límite lleno rechaza el login y la
  persona queda afuera.
- Los tokens vencidos de una cuenta los borra Knox la próxima vez que esa cuenta
  usa la API.

Los días se cambian con `settings.DIAS_DE_VIDA_DEL_TOKEN` y
`settings.DIAS_MAXIMOS_DE_SESION` (ver REST_KNOX en config/settings.py).
"""
from datetime import timedelta

from knox.models import AuthToken
from knox.settings import knox_settings

MAXIMO_DE_SESIONES = 10


def iniciar_sesion(user) -> tuple[AuthToken, str]:
    """Abre una sesión nueva: devuelve el registro del token y la clave para la app.

    La clave no se puede volver a obtener: en la base solo queda su hash.
    """
    # Knox aplica el tope de 90 días solo al renovar; acá se aplica también al crear.
    vida = min(knox_settings.TOKEN_TTL, knox_settings.AUTO_REFRESH_MAX_TTL)
    instancia, clave = AuthToken.objects.create(user, expiry=vida)
    _cerrar_las_menos_usadas(user, nueva=instancia)
    return instancia, clave


def _cerrar_las_menos_usadas(user, nueva: AuthToken) -> None:
    """Deja como mucho MAXIMO_DE_SESIONES: cierra las que llevan más tiempo sin usarse.

    La que se acaba de abrir nunca se cierra. Son pocas por cuenta, así que se ordenan
    en Python: la regla queda escrita aquí y no depende de cómo ordena cada base las
    sesiones sin vencimiento (SQLite y PostgreSQL ponen NULL en puntas distintas).
    """
    otras = list(AuthToken.objects.filter(user=user).exclude(pk=nueva.pk))
    sobran = len(otras) - (MAXIMO_DE_SESIONES - 1)
    if sobran <= 0:
        return
    otras.sort(key=_uso_reciente)
    AuthToken.objects.filter(pk__in=[t.pk for t in otras[:sobran]]).delete()


def _uso_reciente(token: AuthToken) -> tuple:
    """Para ordenar de la sesión usada hace más tiempo a la más reciente.

    Knox no guarda el último uso, pero cada uso corre el vencimiento: cuanto más tarde
    vence, más recién se usó. Dos excepciones cuentan como usadas hace poco:
    - La que ya llegó al tope de 90 días: su vencimiento quedó fijo, y solo llega ahí
      si se usó después del día 60 (90 de tope menos 30 de vida). Por el vencimiento
      parecería la menos usada, y suele ser el teléfono de todos los días.
    - La que no vence (creada a mano en el admin).
    """
    tope = knox_settings.AUTO_REFRESH_MAX_TTL
    # Knox no escribe una renovación de menos de MIN_REFRESH_INTERVAL: puede quedar a
    # ese margen del tope.
    margen = timedelta(seconds=knox_settings.MIN_REFRESH_INTERVAL)
    if token.expiry is None or (tope is not None and token.expiry >= token.created + tope - margen):
        return (1, token.created)
    return (0, token.expiry)


def cerrar_sesion(token: AuthToken) -> None:
    """Cierra solo esta sesión (este teléfono)."""
    token.delete()


def cerrar_todas(user) -> None:
    """Cierra todas las sesiones de la cuenta, en todos sus teléfonos."""
    AuthToken.objects.filter(user=user).delete()
