"""Entrar (o crear la cuenta) con una identidad verificada de Google o Apple.

- Si la identidad (proveedor, sub) ya existe, es su dueño: se le devuelve su cuenta.
- Si es la primera vez y el correo (verificado por el proveedor) ya tiene una
  cuenta en +Vida, no se crea otra ni se une sola: se avisa con qué método
  entrar (`CorreoYaRegistrado`). +Vida no verifica el correo al registrar con
  contraseña, así que unir por coincidir dejaría entrar a quien registró el
  correo de otra persona.
- Si no, hace falta la fecha de nacimiento (la edad decide la FCmáx, el bono
  60+ y la meta de pasos) y **sin ella no se crea nada**.
- Se crea lo mismo que el registro con usuario y contraseña: User, Usuario con
  `usuario_id` público generado por el servidor, y el token (lo crea la señal).
  La cuenta nueva no tiene contraseña: solo se entra con su proveedor.
- La cuenta social guarda el correo verificado (en minúsculas) en `User.email`.
  Con un correo de reenvío de Apple no hay coincidencias posibles: es un límite
  conocido.
"""
import secrets
import uuid
from datetime import date

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction

from Apps.users.models import IdentidadExterna, Usuario
from services.identidad_externa import Identidad

User = get_user_model()


class FaltaFechaNacimiento(Exception):
    """Primera vez con ese proveedor y la app todavía no mandó la fecha de nacimiento."""


class CorreoYaRegistrado(Exception):
    """Ese correo ya tiene cuenta. `metodo`: "contrasena", "google" o "apple"."""

    def __init__(self, metodo: str):
        self.metodo = metodo


class CuentaInactiva(Exception):
    """La cuenta existe pero un administrador la desactivó."""


def _buscar(identidad: Identidad) -> IdentidadExterna | None:
    return (
        IdentidadExterna.objects.select_related("user")
        .filter(proveedor=identidad.proveedor, sub=identidad.sub)
        .first()
    )


def _cuenta_con_correo(correo: str) -> str | None:
    """Con qué método entra quien ya tiene cuenta con este correo, o None si no hay.

    La app guarda el correo como `username` en las cuentas con contraseña; las
    sociales lo guardan en `User.email`.
    """
    user = (
        User.objects.filter(username__iexact=correo).first()
        or User.objects.filter(email__iexact=correo).first()
    )
    if user is None:
        return None
    identidad = user.identidades_externas.order_by("id").first()
    return identidad.proveedor if identidad is not None else "contrasena"


def entrar(identidad: Identidad, birth_date: date | None) -> tuple["User", bool]:
    """Devuelve (usuario de Django, si la cuenta es nueva)."""
    existente = _buscar(identidad)
    if existente is not None:
        if not existente.user.is_active:
            raise CuentaInactiva()
        return existente.user, False

    if identidad.email:
        metodo = _cuenta_con_correo(identidad.email)
        if metodo is not None:
            raise CorreoYaRegistrado(metodo)

    if birth_date is None:
        raise FaltaFechaNacimiento()

    try:
        with transaction.atomic():
            # Sin contraseña (create_user sin password la deja inutilizable).
            user = User.objects.create_user(
                username=f"{identidad.proveedor}-{secrets.token_hex(8)}",
                email=identidad.email or "",
            )
            Usuario.objects.create(
                user=user, usuario_id=str(uuid.uuid4()), birth_date=birth_date,
            )
            IdentidadExterna.objects.create(
                user=user, proveedor=identidad.proveedor, sub=identidad.sub,
            )
    except IntegrityError:
        # Dos peticiones a la vez con la misma identidad nueva: ganó la otra.
        existente = _buscar(identidad)
        if existente is None:
            raise
        return existente.user, False
    return user, True
