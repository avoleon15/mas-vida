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
  más viejas. No se usa TOKEN_LIMIT_PER_USER de Knox porque con el límite lleno
  rechaza el login y la persona queda afuera.
- Los tokens vencidos de una cuenta los borra Knox la próxima vez que esa cuenta
  usa la API.

Los días se cambian con `settings.DIAS_DE_VIDA_DEL_TOKEN` y
`settings.DIAS_MAXIMOS_DE_SESION` (ver REST_KNOX en config/settings.py).
"""
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
    _cerrar_las_mas_viejas(user)
    return instancia, clave


def _cerrar_las_mas_viejas(user) -> None:
    sobrantes = AuthToken.objects.filter(user=user).order_by("-created").values_list(
        "digest", flat=True,
    )[MAXIMO_DE_SESIONES:]
    AuthToken.objects.filter(digest__in=list(sobrantes)).delete()


def cerrar_sesion(token: AuthToken) -> None:
    """Cierra solo esta sesión (este teléfono)."""
    token.delete()


def cerrar_todas(user) -> None:
    """Cierra todas las sesiones de la cuenta, en todos sus teléfonos."""
    AuthToken.objects.filter(user=user).delete()
