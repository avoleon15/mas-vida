from django.utils import timezone
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import AuthenticationFailed

from services import sesiones


class TokenConCaducidad(TokenAuthentication):
    """El mismo `Authorization: Token <clave>` de siempre, pero el token vence a los
    30 días sin uso y cada uso lo renueva. Ver services/sesiones.py.

    Vencido responde 401 igual que un token inválido: la app decide por el código
    y vuelve a pedir inicio de sesión.
    """

    def authenticate_credentials(self, key):
        user, token = super().authenticate_credentials(key)
        ahora = timezone.now()
        if sesiones.vencido(token, ahora):
            raise AuthenticationFailed("El token venció. Vuelve a iniciar sesión.")
        sesiones.registrar_uso(token, ahora)
        return user, token
