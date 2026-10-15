from django.core.exceptions import ObjectNotUpdated
from knox.auth import TokenAuthentication
from rest_framework.exceptions import AuthenticationFailed


class TokenDeSesion(TokenAuthentication):
    """El `Authorization: Token <clave>` de django-rest-knox (ver services/sesiones.py),
    con dos casos que Knox 5.1 responde con 500 y acá son 401, como en Django REST
    Framework:

    - Un encabezado con bytes que no son UTF-8: Knox lo decodifica sin atrapar el error.
    - Un token que otra petición borró (cerrar sesión) mientras esta lo renovaba: Knox
      guarda el vencimiento nuevo con `save(update_fields=...)` y Django avisa con
      `ObjectNotUpdated` que la fila ya no existe.

    Cualquier otro error de la base sigue siendo 500 a propósito: la app toma todo 401
    como "volver a iniciar sesión", y una caída de la base no puede sacar a nadie.
    """

    def authenticate_credentials(self, token):
        try:
            token.decode("utf-8")
        except UnicodeError:
            raise AuthenticationFailed(
                "Invalid token header. Token string should not contain invalid characters."
            )
        return super().authenticate_credentials(token)

    def renew_token(self, auth_token) -> None:
        try:
            super().renew_token(auth_token)
        except ObjectNotUpdated:
            raise AuthenticationFailed("Invalid token.")
