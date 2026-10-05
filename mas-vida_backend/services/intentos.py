"""Límite de intentos fallidos (etapa 10, decidido el 4 oct 2026).

Sin límite, quien tiene un número de póliza (son correlativos) puede adivinar la
fecha de nacimiento del titular probando días, y al acertar ve su nombre, plan y
prima. Lo mismo con las contraseñas del login.

Límites, todos configurables en `settings.LIMITES_DE_INTENTOS` (tipo -> (máximo, segundos)),
que sale de la variable de entorno `LIMITES_DE_INTENTOS` con el formato
`login_ip=300/60,registro_ip=300/3600` (útil para probar en local):

| Tipo              | Qué se cuenta                               | Límite             |
|-------------------|---------------------------------------------|--------------------|
| vincular_poliza   | vinculaciones rechazadas de ese número      | 5 al día, sumando todas las cuentas |
| vincular_cuenta   | vinculaciones rechazadas de esa cuenta      | 5 por hora         |
| login_cuenta      | contraseñas malas para ese usuario          | 5 por minuto       |
| login_ip          | contraseñas malas desde esa IP              | 30 por minuto      |
| registro_ip       | registros intentados desde esa IP           | 30 por hora        |

Solo cuentan los intentos que fallan (salvo el registro, que cuenta todos): quien
acierta a la primera nunca se topa con el límite. El número de póliza y el
usuario se guardan como un hash, no en claro.

Una IP puede ser de mucha gente a la vez (redes de celular, o Docker, donde todas
las peticiones llegan con la misma): por eso el login se limita sobre todo por
CUENTA, y los límites por IP son holgados. Un usuario inexistente cuenta igual
que uno real, así el límite no sirve para saber qué usuarios existen.
"""
import hashlib
import math
from datetime import datetime, timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response

from Apps.users.models import IntentoFallido

VINCULAR_POLIZA = "vincular_poliza"
VINCULAR_CUENTA = "vincular_cuenta"
LOGIN_CUENTA = "login_cuenta"
LOGIN_IP = "login_ip"
REGISTRO_IP = "registro_ip"

HORA = 3600
DIA = 24 * HORA

LIMITES = {
    VINCULAR_POLIZA: (5, DIA),
    VINCULAR_CUENTA: (5, HORA),
    LOGIN_CUENTA: (5, 60),
    LOGIN_IP: (30, 60),
    REGISTRO_IP: (30, HORA),
}

# Los intentos se guardan el doble de la ventana más larga y después se borran.
DIAS_QUE_SE_GUARDAN = 2


class Bloqueado(Exception):
    """Ya se pasó el límite: hay que esperar `reintentar_en` segundos."""

    def __init__(self, reintentar_en: int):
        super().__init__(reintentar_en)
        self.reintentar_en = reintentar_en

    def respuesta(self) -> Response:
        return Response(
            {
                "error": "demasiados_intentos",
                "mensaje": "Demasiados intentos. Inténtalo de nuevo más tarde.",
                "reintentar_en": self.reintentar_en,
            },
            status=status.HTTP_429_TOO_MANY_REQUESTS,
            headers={"Retry-After": str(self.reintentar_en)},
        )


def limite_de(tipo: str) -> tuple[int, int]:
    return getattr(settings, "LIMITES_DE_INTENTOS", {}).get(tipo, LIMITES[tipo])


def clave_de_poliza(aseguradora: str, numero: str) -> str:
    """Hash del número de póliza (sin distinguir mayúsculas ni espacios) y su aseguradora."""
    normalizado = f"{aseguradora.strip().casefold()}|{numero.strip().casefold()}"
    return hashlib.sha256(normalizado.encode()).hexdigest()


def clave_de_usuario(nombre) -> str:
    """Hash del nombre de usuario tal como lo escribió quien intenta entrar (sin distinguir mayúsculas)."""
    normalizado = nombre.strip().casefold() if isinstance(nombre, str) else ""
    return hashlib.sha256(f"usuario|{normalizado}".encode()).hexdigest()


def ip_de(request) -> str:
    """La IP de quien llama.

    Detrás de un servidor web o balanceador, `REMOTE_ADDR` es el del proxy y la
    real viene en `X-Forwarded-For`. Solo se lee con `NUM_PROXIES_CONFIABLES`
    configurado (cuántos proxies propios hay delante): cualquiera puede mandar
    ese encabezado y falsearlo, así que se cuenta desde la derecha.
    """
    proxies = getattr(settings, "NUM_PROXIES_CONFIABLES", 0)
    reenviadas = request.META.get("HTTP_X_FORWARDED_FOR", "")
    if proxies and reenviadas:
        direcciones = [d.strip() for d in reenviadas.split(",") if d.strip()]
        if len(direcciones) >= proxies:
            return direcciones[-proxies]
    return request.META.get("REMOTE_ADDR", "desconocida")


def revisar(tipo: str, clave: str, ahora: datetime | None = None) -> None:
    """Lanza Bloqueado si esa clave ya llegó al límite en la ventana."""
    ahora = ahora or timezone.now()
    maximo, ventana = limite_de(tipo)
    fechas = list(
        IntentoFallido.objects
        .filter(tipo=tipo, clave=clave, creado_en__gt=ahora - timedelta(seconds=ventana))
        .order_by("creado_en")
        .values_list("creado_en", flat=True)
    )
    if len(fechas) < maximo:
        return
    # Se libera cuando sale de la ventana el intento que deja la cuenta debajo del máximo.
    libera = fechas[len(fechas) - maximo] + timedelta(seconds=ventana)
    raise Bloqueado(max(1, math.ceil((libera - ahora).total_seconds())))


def registrar(tipo: str, clave: str, ahora: datetime | None = None) -> None:
    ahora = ahora or timezone.now()
    IntentoFallido.objects.create(tipo=tipo, clave=clave, creado_en=ahora)
    IntentoFallido.objects.filter(
        creado_en__lt=ahora - timedelta(days=DIAS_QUE_SE_GUARDAN)
    ).delete()
