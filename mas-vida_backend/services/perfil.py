"""Perfil de la persona: lo que la pantalla de Perfil muestra de su propia cuenta.

Todo sale de lo que el servidor ya sabe. Nada de esto viaja en el sync ni se
calcula en la app: la edad, por ejemplo, es la que usa el servidor para los
puntos (la de la aseguradora si hay póliza verificada, si no la del registro).
"""
from datetime import date, datetime, timedelta

from django.db.models import Max
from django.utils import timezone

from Apps.activities.models import Muestra, MuestraBPM, Sesion
from Apps.policies.models import PolizaVinculada
from services.daily_scoring import fecha_nacimiento_efectiva
from services.device import clave_dispositivo
from services.hearth_rate import calculate_age

# Un dispositivo cuenta como vinculado si mandó datos en este tiempo. Un reloj
# que se dejó de usar sale solo de la lista.
DIAS_DE_DISPOSITIVO_RECIENTE = 30

_CAMPOS_DISPOSITIVO = (
    "fuente_bundle", "fuente_nombre", "dispositivo_nombre",
    "dispositivo_modelo", "dispositivo_fabricante",
)


def correo_de(user) -> str | None:
    """El correo de la cuenta.

    En las cuentas con contraseña la app lo guarda como `username`; las cuentas
    de Google y Apple lo guardan en `User.email`. Si no hay ninguno, None (por
    ejemplo `google-4f2a…`, que es un nombre generado).
    """
    if user.email:
        return user.email
    return user.username if "@" in user.username else None


def nombre_de(usuario) -> str | None:
    """Nombre y apellido que dio la aseguradora; solo con póliza verificada."""
    poliza = PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion=PolizaVinculada.EstadoVerificacion.VERIFICADA,
    ).first()
    if poliza is None:
        return None
    completo = f"{poliza.nombre or ''} {poliza.apellido or ''}".strip()
    return completo or None


def dispositivos_de(usuario, ahora: datetime | None = None) -> list[dict]:
    """Dispositivos que mandaron datos en los últimos 30 días, el más reciente primero.

    Un dispositivo es el mismo si comparten fuente, modelo y fabricante (la
    misma clave que usa el puntaje); el nombre que se muestra es el de su dato
    más nuevo.
    """
    ahora = ahora or timezone.now()
    desde = ahora - timedelta(days=DIAS_DE_DISPOSITIVO_RECIENTE)

    por_clave: dict[tuple, dict] = {}
    for modelo in (Muestra, MuestraBPM, Sesion):
        filas = (
            modelo.objects.filter(usuario=usuario, inicio__gte=desde)
            .values(*_CAMPOS_DISPOSITIVO)
            .annotate(ultimo=Max("inicio"))
        )
        for fila in filas:
            clave = clave_dispositivo(fila)
            actual = por_clave.get(clave)
            if actual is None or fila["ultimo"] > actual["ultimo"]:
                por_clave[clave] = fila

    # Para no repetir el mismo dispositivo con dos nombres distintos, el último
    # dato manda; el empate se resuelve por nombre para que el orden no baile.
    dispositivos = [
        {
            "nombre": fila["dispositivo_nombre"] or fila["fuente_nombre"],
            "modelo": fila["dispositivo_modelo"] or None,
            "fuente": fila["fuente_nombre"],
            "ultimo_dato": timezone.localtime(fila["ultimo"]).date().isoformat(),
            "_orden": fila["ultimo"],
        }
        for fila in por_clave.values()
    ]
    dispositivos.sort(key=lambda d: (d["nombre"] or ""))
    dispositivos.sort(key=lambda d: d["_orden"], reverse=True)
    for d in dispositivos:
        del d["_orden"]
    return dispositivos


def resumen(usuario, hoy: date | None = None) -> dict:
    hoy = hoy or timezone.localdate()
    nacimiento = fecha_nacimiento_efectiva(usuario)
    poliza_verificada = PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion=PolizaVinculada.EstadoVerificacion.VERIFICADA,
    ).exists()
    return {
        "usuario_id": usuario.usuario_id,
        "correo": correo_de(usuario.user),
        "nombre": nombre_de(usuario),
        "fecha_nacimiento": nacimiento.isoformat(),
        "edad": calculate_age(nacimiento, hoy),
        "poliza_verificada": poliza_verificada,
        "dispositivos": dispositivos_de(usuario),
    }
