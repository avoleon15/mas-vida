"""Póliza vinculada: gate de beneficios, verificación y retroactividad.

Dos estados de cuenta (arquitectura-cuentas-vivo.md): cuenta base (gratis) y
cuenta con póliza vinculada Y verificada. "pendiente" y "rechazada" cuentan
exactamente igual que no tener póliza: no hay un tercer estado.

Retroactividad al verificar (decidido 19 sep): si la fecha de nacimiento del
registro coincide con la que confirma la aseguradora, todo lo ganado en la
cuenta base se acredita tal cual. Si NO coincide, no hay retroactividad: la
cuenta arranca en cero desde la verificación, y queda constancia en el ledger
(una fila `retroactivo_denegado` por día anulado) en vez de ignorar el
histórico sin dejar rastro. Se cuenta desde la verificación y no desde la
vinculación porque los días intermedios también se calcularon con una edad
sin confirmar, que es justo lo que esta regla evita reprocesar.

Las monedas ganadas antes del corte también se anulan (ver
services.monedas.anular_ganadas_antes_de).
"""
from collections import defaultdict
from datetime import date

from django.db import transaction
from django.utils import timezone

from Apps.activities.models import ResumenDiario
from Apps.policies.models import PolizaVinculada
from Apps.poincs.models import Ledger
from services import monedas

PENDIENTE = "pendiente"
VERIFICADA = "verificada"
RECHAZADA = "rechazada"

# Filas que componen los puntos de un día (incluye el retroactivo anulado,
# para que un día anulado quede en neto 0 y no se vuelva a ajustar).
TIPOS_DEL_DIA = (
    Ledger.TipoLedger.PASOS,
    Ledger.TipoLedger.INTENSIDAD,
    Ledger.TipoLedger.AJUSTE_MANUAL,
    Ledger.TipoLedger.RETROACTIVO_DENEGADO,
)


class PolizaYaVinculada(Exception):
    """El usuario ya tiene una póliza pendiente o verificada."""


class FaltaFechaConfirmada(Exception):
    """No se puede verificar sin la fecha de nacimiento que dio la aseguradora."""


def poliza_de(usuario) -> PolizaVinculada | None:
    return PolizaVinculada.objects.filter(usuario=usuario).first()


def tiene_poliza_verificada(usuario) -> bool:
    """Gate duro de todo lo que implica dinero o premio."""
    return PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion=VERIFICADA
    ).exists()


def fecha_corte_sin_retroactivo(usuario) -> date | None:
    """Día desde el cual cuentan los puntos, si se denegó el retroactivo.

    None = el histórico cuenta completo (sin póliza, pendiente, rechazada, o
    verificada con fecha de nacimiento coincidente).
    """
    poliza = PolizaVinculada.objects.filter(
        usuario=usuario, estado_verificacion=VERIFICADA
    ).first()
    if (
        poliza is None
        or poliza.birth_date_confirmada is None
        or poliza.fecha_verificacion is None
        or poliza.birth_date_confirmada == usuario.birth_date
    ):
        return None
    return timezone.localtime(poliza.fecha_verificacion).date()


@transaction.atomic
def vincular(usuario, policy_number: str, insurer: str, policy_start_date: date) -> PolizaVinculada:
    """Crea la póliza en estado pendiente. Una rechazada se puede volver a enviar."""
    existente = PolizaVinculada.objects.select_for_update().filter(usuario=usuario).first()
    if existente is not None and existente.estado_verificacion != RECHAZADA:
        raise PolizaYaVinculada(existente.estado_verificacion)

    datos = dict(
        policy_number=policy_number,
        insurer=insurer,
        policy_start_date=policy_start_date,
        birth_date_confirmada=None,
        estado_verificacion=PENDIENTE,
        fecha_verificacion=None,
    )
    if existente is None:
        return PolizaVinculada.objects.create(usuario=usuario, **datos)

    for campo, valor in datos.items():
        setattr(existente, campo, valor)
    existente.save()
    return existente


@transaction.atomic
def verificar(poliza: PolizaVinculada, ahora=None) -> str:
    """Marca la póliza como verificada y aplica la regla de retroactividad.

    Devuelve "aplicado", "denegado" o "sin_cambios" (ya estaba verificada).
    """
    if poliza.estado_verificacion == VERIFICADA:
        return "sin_cambios"
    if poliza.birth_date_confirmada is None:
        raise FaltaFechaConfirmada()

    ahora = ahora or timezone.now()
    poliza.estado_verificacion = VERIFICADA
    poliza.fecha_verificacion = ahora
    poliza.save()

    usuario = poliza.usuario
    if poliza.birth_date_confirmada == usuario.birth_date:
        return "aplicado"

    denegar_retroactivo(usuario, timezone.localtime(ahora).date())
    return "denegado"


@transaction.atomic
def rechazar(poliza: PolizaVinculada) -> None:
    """Rechazada = igual que sin póliza. No toca el ledger."""
    if poliza.estado_verificacion == VERIFICADA:
        raise ValueError("Una póliza verificada no se rechaza")
    poliza.estado_verificacion = RECHAZADA
    poliza.fecha_verificacion = None
    poliza.save()


def denegar_retroactivo(usuario, corte: date) -> int:
    """Anula en el ledger los puntos de los días anteriores a `corte`.

    Append-only: una fila negativa por día, nunca se edita lo que ya estaba.
    Idempotente: un día que ya quedó en neto 0 no genera otra fila.
    Devuelve cuántos días se anularon.
    """
    por_fecha = defaultdict(list)
    filas = (
        Ledger.objects
        .filter(usuario=usuario, fecha__lt=corte, tipo__in=TIPOS_DEL_DIA)
        .order_by("fecha", "id")
    )
    for fila in filas:
        por_fecha[fila.fecha].append(fila)

    anulados = 0
    for fecha, del_dia in por_fecha.items():
        neto = sum(f.puntos for f in del_dia)
        if neto == 0:
            continue
        ultima = del_dia[-1]
        Ledger.objects.create(
            usuario=usuario,
            fecha=fecha,
            tipo=Ledger.TipoLedger.RETROACTIVO_DENEGADO,
            puntos=-neto,
            # Se copian para que el historial siga mostrando la actividad del día.
            puntos_pasos=ultima.puntos_pasos,
            puntos_intensidad=ultima.puntos_intensidad,
            tope_diario_aplicado=ultima.tope_diario_aplicado,
            version_regla=ultima.version_regla,
        )
        anulados += 1

    # Las monedas ganadas antes del corte tampoco cuentan.
    monedas.anular_ganadas_antes_de(usuario, corte)

    # El resumen del dashboard debe decir lo mismo que el ledger.
    ResumenDiario.objects.filter(usuario=usuario, fecha__lt=corte).update(puntos_dia=0)
    return anulados
