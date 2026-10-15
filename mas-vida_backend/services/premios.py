"""Premios y cupones: catálogo, canje con monedas y los cupones del usuario.

Reglas (CLAUDE.md y contrato-tecnico.md):
- Canjear exige póliza verificada. Sin ella el catálogo se ve igual, pero la
  compra queda bloqueada.
- Canjear descuenta las monedas y crea el cupón en la MISMA transacción: nunca
  queda un descuento sin cupón ni un cupón sin descuento.
- Un cupón dura 3 semanas (21 días) desde que se canjea o se gana, aparte de las
  monedas (decidido el 4 oct 2026; antes eran 60 días).
- El estado `vencido` no se guarda: se calcula de la fecha de vencimiento, así
  no hace falta ningún proceso que lo marque.
"""
import secrets
from datetime import date, datetime, timedelta

from django.db import IntegrityError, transaction
from django.utils import timezone

from Apps.coins.models import Canje, Patrocinio, Premio
from services import monedas, polizas
from services.tiempo import hoy as hoy_guatemala

# 3 semanas, igual para el que se canjea con monedas y para el que se gana de un
# patrocinio. Los cupones ya emitidos conservan su fecha: solo cambia el de ahora en adelante.
DIAS_DE_UN_CUPON = 21

ACTIVO = "activo"
USADO = "usado"
VENCIDO = "vencido"

# Sin 0/O ni 1/I/L: el código se lee o se teclea en una caja.
_ALFABETO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


class SinPolizaVerificada(Exception):
    """Canjear es de quien tiene póliza verificada."""


class PremioNoDisponible(Exception):
    """El premio está apagado o ya pasó su fecha de canje."""


def _codigo() -> str:
    parte = lambda: "".join(secrets.choice(_ALFABETO) for _ in range(4))  # noqa: E731
    return f"MV-{parte()}-{parte()}"


def premio_disponible(premio: Premio, hoy: date | None = None) -> bool:
    hoy = hoy or hoy_guatemala()
    return premio.activo and (premio.vigente_hasta is None or premio.vigente_hasta >= hoy)


def catalogo(hoy: date | None = None) -> list[Premio]:
    """Los premios que se pueden canjear hoy, en un orden estable."""
    hoy = hoy or hoy_guatemala()
    return [
        premio
        for premio in Premio.objects.filter(activo=True).order_by("categoria", "nombre", "id")
        if premio_disponible(premio, hoy)
    ]


def canjear(usuario, premio: Premio, ahora: datetime | None = None) -> Canje:
    """Canjea `premio` con monedas y devuelve el cupón.

    Lanza SinPolizaVerificada, PremioNoDisponible o monedas.SaldoInsuficiente.
    """
    ahora = ahora or timezone.now()
    hoy = timezone.localtime(ahora).date()

    if not polizas.tiene_poliza_verificada(usuario):
        raise SinPolizaVerificada()
    if not premio_disponible(premio, hoy):
        raise PremioNoDisponible()

    # Colisión de códigos: casi imposible, pero el campo es único y se reintenta.
    for _ in range(5):
        codigo = _codigo()
        try:
            with transaction.atomic():
                # Un premio gratis (costo 0) no mueve el ledger.
                if premio.costo_monedas:
                    monedas.gastar(usuario, premio.costo_monedas, fecha=hoy)
                return Canje.objects.create(
                    usuario=usuario,
                    premio=premio,
                    costo_monedas=premio.costo_monedas,
                    fecha_canje=ahora,
                    fecha_expiracion_cupon=hoy + timedelta(days=DIAS_DE_UN_CUPON),
                    estado=Canje.Estado.ACTIVO,
                    codigo=codigo,
                    origen=Canje.Origen.TIENDA,
                )
        except IntegrityError:
            # Solo se reintenta si lo que chocó fue el código; otro error sube.
            if not Canje.objects.filter(codigo=codigo).exists():
                raise
    raise RuntimeError("No se pudo generar un código de cupón único")


def ganar_cupon(
    usuario, patrocinio: Patrocinio, origen: str, ganado_en: str, ahora: datetime | None = None,
) -> Canje | None:
    """Crea el cupón que da un patrocinio (semana o podio de La Liga). No cuesta monedas.

    Un patrocinio da un solo cupón por usuario: si ya lo tiene devuelve None, así
    que correr el cierre dos veces no duplica. Quien llama decide si el usuario
    tiene derecho (services.patrocinios).
    """
    ahora = ahora or timezone.now()
    hoy = timezone.localtime(ahora).date()

    for _ in range(5):
        if Canje.objects.filter(usuario=usuario, patrocinio=patrocinio).exists():
            return None
        codigo = _codigo()
        try:
            with transaction.atomic():
                return Canje.objects.create(
                    usuario=usuario,
                    premio=patrocinio.premio,
                    costo_monedas=0,
                    fecha_canje=ahora,
                    fecha_expiracion_cupon=hoy + timedelta(days=DIAS_DE_UN_CUPON),
                    estado=Canje.Estado.ACTIVO,
                    codigo=codigo,
                    origen=origen,
                    ganado_en=ganado_en,
                    beneficio=patrocinio.cupon,
                    patrocinio=patrocinio,
                )
        except IntegrityError:
            # Chocó el código (se reintenta) o ya existía este cupón (arriba).
            if not Canje.objects.filter(codigo=codigo).exists() and not Canje.objects.filter(
                usuario=usuario, patrocinio=patrocinio,
            ).exists():
                raise
    raise RuntimeError("No se pudo generar un código de cupón único")


def estado_de(canje: Canje, hoy: date | None = None) -> str:
    hoy = hoy or hoy_guatemala()
    if canje.estado == Canje.Estado.USADO:
        return USADO
    if canje.estado == Canje.Estado.EXPIRADO or canje.fecha_expiracion_cupon < hoy:
        return VENCIDO
    return ACTIVO


def cupones_de(usuario, hoy: date | None = None) -> list[Canje]:
    """Todos los cupones del usuario: primero los activos (el que vence antes
    arriba) y después los usados y vencidos, del más reciente al más viejo."""
    hoy = hoy or hoy_guatemala()
    canjes = list(Canje.objects.filter(usuario=usuario).select_related("premio"))
    activos = sorted(
        (c for c in canjes if estado_de(c, hoy) == ACTIVO),
        key=lambda c: (c.fecha_expiracion_cupon, c.pk),
    )
    otros = sorted(
        (c for c in canjes if estado_de(c, hoy) != ACTIVO),
        key=lambda c: (c.fecha_canje, c.pk),
        reverse=True,
    )
    return activos + otros


def marcar_usado(canje: Canje, ahora: datetime | None = None) -> bool:
    """El comercio entregó el beneficio. Devuelve False si ya no estaba activo."""
    ahora = ahora or timezone.now()
    if estado_de(canje, timezone.localtime(ahora).date()) != ACTIVO:
        return False
    canje.estado = Canje.Estado.USADO
    canje.usado_en = ahora
    canje.save(update_fields=["estado", "usado_en"])
    return True
