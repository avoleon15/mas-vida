"""Inicio de sesión con Google y Apple: verificar la credencial que firma el proveedor.

La app recibe del proveedor un token (JWT) y se lo manda al servidor; el
servidor comprueba que sea de verdad de Google o de Apple y que se haya emitido
PARA esta app. Nada se acepta por confianza: firma, emisor, audiencia y
vencimiento se verifican siempre.

Reglas (contrato-tecnico.md, "Inicio de sesión con Google y Apple"):
- La identidad es el par (proveedor, `sub`): el `sub` es estable y único por
  persona en cada proveedor. El correo NO identifica a nadie: puede cambiar y
  Apple puede ocultarlo (entrega uno de reenvío). Se lee solo para avisar si ese
  correo ya tiene cuenta en +Vida, y solo si el proveedor dice que está
  verificado.
- Un proveedor sin identificadores de cliente configurados queda apagado.
- Nunca se escribe la credencial en logs ni en mensajes de error: es tan
  sensible como una contraseña.
"""
import hashlib
import hmac
from dataclasses import dataclass

import jwt
from django.conf import settings
from jwt import PyJWKClient

GOOGLE = "google"
APPLE = "apple"

_PROVEEDORES = {
    GOOGLE: {
        "claves": "https://www.googleapis.com/oauth2/v3/certs",
        "emisores": ["https://accounts.google.com", "accounts.google.com"],
        "audiencias": lambda: settings.GOOGLE_CLIENT_IDS,
    },
    APPLE: {
        "claves": "https://appleid.apple.com/auth/keys",
        "emisores": ["https://appleid.apple.com"],
        "audiencias": lambda: settings.APPLE_CLIENT_IDS,
    },
}

PROVEEDORES = tuple(_PROVEEDORES)

# Segundos de tolerancia entre el reloj del servidor y el del proveedor: sin
# esto, un token recién emitido se rechaza si el servidor va unos segundos atrás.
MARGEN_DE_RELOJ = 60


class CredencialInvalida(Exception):
    """El token no es de ese proveedor, no es para esta app, venció o no coincide el nonce."""


class ProveedorNoConfigurado(Exception):
    """Falta el identificador de cliente de ese proveedor en la configuración."""


class ProveedorNoDisponible(Exception):
    """No se pudieron pedir las claves públicas al proveedor (red caída)."""


@dataclass(frozen=True)
class Identidad:
    proveedor: str
    sub: str
    # En minúsculas y solo si el proveedor dice que es de esa persona; si no, None.
    email: str | None = None


_clientes: dict[str, PyJWKClient] = {}


def _clave_de(proveedor: str, credencial: str):
    """La clave pública con la que firmó el proveedor este token.

    PyJWKClient guarda las claves en memoria, así que no se pide la lista a
    Google o a Apple en cada inicio de sesión. Es el único punto con red: las
    pruebas lo reemplazan.
    """
    if proveedor not in _clientes:
        _clientes[proveedor] = PyJWKClient(
            _PROVEEDORES[proveedor]["claves"], cache_keys=True, timeout=5,
        )
    try:
        return _clientes[proveedor].get_signing_key_from_jwt(credencial).key
    except jwt.PyJWKClientConnectionError as error:
        raise ProveedorNoDisponible() from error
    except jwt.PyJWTError as error:
        # No es un JWT, o su `kid` no es de las claves del proveedor.
        raise CredencialInvalida() from error


def _nonce_coincide(esperado: str, en_el_token: str) -> bool:
    """El token lleva el nonce tal cual o su SHA-256 en hexadecimal (así lo hace Apple)."""
    # En bytes: compare_digest no acepta textos con caracteres fuera de ASCII.
    token = en_el_token.encode()
    candidatos = (esperado.encode(), hashlib.sha256(esperado.encode()).hexdigest().encode())
    return any(hmac.compare_digest(token, c) for c in candidatos)


def _correo_verificado(claims: dict) -> str | None:
    """El correo del token, solo si el proveedor asegura que está verificado.

    Google manda `email_verified` como booleano y Apple como el texto "true".
    """
    correo = claims.get("email")
    if not isinstance(correo, str) or "@" not in correo:
        return None
    if str(claims.get("email_verified")).lower() != "true":
        return None
    return correo.strip().lower()


def verificar(proveedor: str, credencial: str, nonce: str | None = None) -> Identidad:
    """Verifica la credencial y devuelve quién es. Lanza las excepciones de arriba.

    Si el token trae `nonce` la app tiene que mandarlo (y tiene que coincidir):
    es lo que impide que alguien reutilice un token que le robó a otra persona.
    """
    datos = _PROVEEDORES[proveedor]
    audiencias = datos["audiencias"]()
    if not audiencias:
        raise ProveedorNoConfigurado()

    clave = _clave_de(proveedor, credencial)
    try:
        claims = jwt.decode(
            credencial,
            clave,
            algorithms=["RS256"],
            audience=audiencias,
            issuer=datos["emisores"],
            options={"require": ["exp", "iss", "aud", "sub"]},
            leeway=MARGEN_DE_RELOJ,
        )
    except jwt.PyJWTError as error:
        raise CredencialInvalida() from error

    sub = claims["sub"]
    if not isinstance(sub, str) or not sub:
        raise CredencialInvalida()

    en_el_token = claims.get("nonce")
    if en_el_token is not None or nonce is not None:
        if not (
            isinstance(en_el_token, str) and nonce and _nonce_coincide(nonce, en_el_token)
        ):
            raise CredencialInvalida()

    return Identidad(proveedor=proveedor, sub=sub, email=_correo_verificado(claims))
