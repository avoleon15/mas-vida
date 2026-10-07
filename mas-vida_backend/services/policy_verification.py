"""Verificación de una póliza contra el registro de la aseguradora.

Hoy el registro es la tabla RegistroAseguradora (un documento simulado, solo
para pruebas). Cuando exista la API real de la aseguradora, se escribe otra
clase con el mismo método `buscar` y se la pasa a `verificar_poliza`; la lógica
de verificación no cambia.
"""
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Optional, Protocol

from django.utils import timezone

VERIFICADA = "verificada"
RECHAZADA = "rechazada"

NO_EXISTE = "no_existe"
ASEGURADORA_NO_COINCIDE = "aseguradora_no_coincide"
NO_VIGENTE = "no_vigente"
FECHA_NACIMIENTO_NO_COINCIDE = "fecha_nacimiento_no_coincide"


@dataclass(frozen=True)
class DatosPoliza:
    """Lo que la aseguradora dice de una póliza, sin importar de dónde venga."""

    numero_poliza: str
    aseguradora: str
    fecha_nacimiento: date
    vigencia_inicio: date
    vigencia_fin: date  # fecha de la próxima renovación anual, no un vencimiento
    vigente: bool  # False solo si la aseguradora la canceló o la suspendió
    nombre: str = ""
    apellido: str = ""
    plan: str = ""
    prima_anual_gtq: Optional[Decimal] = None


class FuenteRegistro(Protocol):
    """Cualquier cosa que sepa buscar una póliza por su número."""

    def buscar(self, numero_poliza: str) -> Optional[DatosPoliza]:
        ...


class FuenteTablaRegistro:
    """Fuente de pruebas: lee la tabla RegistroAseguradora."""

    def buscar(self, numero_poliza: str) -> Optional[DatosPoliza]:
        # Import acá y no arriba: los modelos no se pueden importar antes de que
        # Django termine de cargar las apps, y este módulo se importa antes.
        from Apps.policies.models import RegistroAseguradora

        registro = RegistroAseguradora.objects.filter(
            numero_poliza__iexact=numero_poliza
        ).first()
        if registro is None:
            return None
        return DatosPoliza(
            numero_poliza=registro.numero_poliza,
            aseguradora=registro.aseguradora,
            fecha_nacimiento=registro.fecha_nacimiento,
            vigencia_inicio=registro.vigencia_inicio,
            vigencia_fin=registro.vigencia_fin,
            vigente=registro.estado == RegistroAseguradora.Estado.VIGENTE,
            nombre=registro.nombre,
            apellido=registro.apellido,
            plan=registro.plan,
            prima_anual_gtq=registro.prima_anual_gtq,
        )


def _hoy() -> date:
    # Función aparte para poder fijar la fecha en las pruebas.
    return timezone.localdate()


@dataclass(frozen=True)
class ResultadoVerificacion:
    estado: str
    motivo: Optional[str]
    # Lo que dijo la aseguradora; nulo si la póliza no existe.
    datos: Optional[DatosPoliza]


def verificar_con_datos(
    policy_number: str,
    insurer: str,
    birth_date: date,
    hoy: Optional[date] = None,
    fuente: Optional[FuenteRegistro] = None,
) -> ResultadoVerificacion:
    """Verifica y devuelve también los datos de la aseguradora.

    Se verifica solo si la póliza existe, la aseguradora coincide, no está
    cancelada ni suspendida, y la fecha de nacimiento coincide. Cualquier otro
    caso es rechazo, con el primer motivo que falle, en este orden.

    Las fechas NO se miran (2 oct 2026): la póliza es anual y se renueva, así
    que pasada su fecha de renovación sigue valiendo. Solo la deja sin valer
    que la aseguradora la cancele o la suspenda.
    """
    # `hoy` se sigue aceptando por compatibilidad, pero ya no decide nada:
    # las fechas de la póliza no se usan para rechazar (ver arriba).
    fuente = fuente or FuenteTablaRegistro()

    datos = fuente.buscar(policy_number.strip())
    if datos is None:
        return ResultadoVerificacion(RECHAZADA, NO_EXISTE, None)

    if datos.aseguradora.strip().casefold() != insurer.strip().casefold():
        return ResultadoVerificacion(RECHAZADA, ASEGURADORA_NO_COINCIDE, datos)

    if not datos.vigente:
        return ResultadoVerificacion(RECHAZADA, NO_VIGENTE, datos)

    if datos.fecha_nacimiento != birth_date:
        return ResultadoVerificacion(RECHAZADA, FECHA_NACIMIENTO_NO_COINCIDE, datos)

    return ResultadoVerificacion(VERIFICADA, None, datos)


def verificar_poliza(
    usuario,
    policy_number: str,
    insurer: str,
    birth_date: date,
    hoy: Optional[date] = None,
    fuente: Optional[FuenteRegistro] = None,
):
    """Devuelve (estado, motivo): ("verificada", None) o ("rechazada", motivo).

    `usuario` todavía no se usa; queda en la firma para cuando la comparación
    con la fecha de nacimiento del registro (retroactividad) necesite al
    usuario.
    """
    resultado = verificar_con_datos(policy_number, insurer, birth_date, hoy, fuente)
    return resultado.estado, resultado.motivo
