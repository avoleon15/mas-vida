"""Ayudas para las pruebas que necesitan una sesión."""
from services import sesiones


def token_de(user) -> str:
    """Abre una sesión para `user`, como el login, y devuelve la clave del token."""
    return sesiones.iniciar_sesion(user)[1]
