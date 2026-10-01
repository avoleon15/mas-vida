"""Monedas: se ganan (objetivo semanal, La Liga), se gastan en Premios y caducan.

MonedaLedger es append-only: ganar, gastar, expirar y ajustar son filas
nuevas, nunca se edita una vieja. El saldo no se guarda en ningún lado: se
recalcula recorriendo el ledger.

Caducidad: cada ganancia es un "lote" que vence a los 90 días (se puede usar
hasta el último día inclusive). Todo descuento (canje, expiración, ajuste
negativo) consume primero el lote que vence antes. Antes de leer o mover el
saldo se asientan las expiraciones pendientes, así un canje nunca consume
monedas ya vencidas.

Se ganan con o sin póliza; lo que exige póliza verificada es GASTARLAS, y eso
lo valida quien llama a `gastar`, no este módulo.
"""
from dataclasses import dataclass
from datetime import date, timedelta

from django.db import transaction

from Apps.coins.models import MonedaLedger
from Apps.users.models import Usuario
from services.reglas import version_regla_vigente
from services.tiempo import hoy as hoy_guatemala

TOPE_MONEDAS = 100
AVISO_MONEDAS = 80
DIAS_CADUCIDAD_MONEDAS = 90


class SaldoInsuficiente(Exception):
    def __init__(self, saldo, costo):
        super().__init__(f"Saldo {saldo} insuficiente para {costo}")
        self.saldo = saldo
        self.costo = costo


@dataclass
class Lote:
    restante: int
    fecha: date                    # día en que se ganó
    fecha_expiracion: date | None  # None = no vence


@dataclass
class ResultadoAcreditacion:
    acreditadas: int
    perdidas_por_tope: int
    saldo: int

    @property
    def aviso_80(self) -> bool:
        """Dispara el modal de aviso: saldo resultante >= 80 (no == 80)."""
        return self.saldo >= AVISO_MONEDAS


def _orden_de_consumo(lote: Lote):
    return (lote.fecha_expiracion is None, lote.fecha_expiracion or date.max)


def lotes_vivos(usuario) -> list[Lote]:
    """Recorre el ledger y devuelve lo que queda de cada ganancia."""
    lotes: list[Lote] = []
    for mov in MonedaLedger.objects.filter(usuario=usuario).order_by("id"):
        if mov.cantidad > 0:
            lotes.append(Lote(mov.cantidad, mov.fecha, mov.fecha_expiracion))
            continue

        por_descontar = -mov.cantidad
        lotes.sort(key=_orden_de_consumo)
        for lote in lotes:
            tomado = min(lote.restante, por_descontar)
            lote.restante -= tomado
            por_descontar -= tomado
            if por_descontar == 0:
                break
        lotes = [lote for lote in lotes if lote.restante > 0]

    return sorted(lotes, key=_orden_de_consumo)


def _bloquear(usuario):
    """Serializa los movimientos de monedas de un mismo usuario (Postgres)."""
    Usuario.objects.select_for_update().get(pk=usuario.pk)


def expirar_vencidas(usuario, hoy: date | None = None) -> int:
    """Asienta como `expiracion` los lotes vencidos. Devuelve cuántas expiraron."""
    hoy = hoy or hoy_guatemala()
    vencidas = sum(
        lote.restante
        for lote in lotes_vivos(usuario)
        if lote.fecha_expiracion is not None and lote.fecha_expiracion < hoy
    )
    if vencidas:
        MonedaLedger.objects.create(
            usuario=usuario,
            cantidad=-vencidas,
            tipo=MonedaLedger.Tipo.EXPIRACION,
            fecha=hoy,
            version_regla=version_regla_vigente(hoy),
        )
    return vencidas


def saldo(usuario, hoy: date | None = None) -> int:
    with transaction.atomic():
        _bloquear(usuario)
        expirar_vencidas(usuario, hoy)
        return sum(lote.restante for lote in lotes_vivos(usuario))


def acreditar(usuario, cantidad: int, tipo: str, fecha: date | None = None) -> ResultadoAcreditacion:
    """Suma monedas respetando el tope de 100: el excedente se pierde."""
    if cantidad <= 0:
        raise ValueError("Solo se acreditan cantidades positivas")
    fecha = fecha or hoy_guatemala()

    with transaction.atomic():
        _bloquear(usuario)
        expirar_vencidas(usuario, fecha)
        previo = sum(lote.restante for lote in lotes_vivos(usuario))
        acreditadas = max(0, min(cantidad, TOPE_MONEDAS - previo))
        if acreditadas:
            MonedaLedger.objects.create(
                usuario=usuario,
                cantidad=acreditadas,
                tipo=tipo,
                fecha=fecha,
                fecha_expiracion=fecha + timedelta(days=DIAS_CADUCIDAD_MONEDAS),
                version_regla=version_regla_vigente(fecha),
            )

    return ResultadoAcreditacion(
        acreditadas=acreditadas,
        perdidas_por_tope=cantidad - acreditadas,
        saldo=previo + acreditadas,
    )


def gastar(usuario, cantidad: int, fecha: date | None = None) -> int:
    """Descuenta monedas por un canje. Devuelve el saldo resultante.

    No valida la póliza: eso es del canje. Pensada para llamarse dentro de la
    transacción del canje, para que el cupón y el descuento se escriban juntos.
    """
    if cantidad <= 0:
        raise ValueError("Solo se gastan cantidades positivas")
    fecha = fecha or hoy_guatemala()

    with transaction.atomic():
        _bloquear(usuario)
        expirar_vencidas(usuario, fecha)
        disponible = sum(lote.restante for lote in lotes_vivos(usuario))
        if disponible < cantidad:
            raise SaldoInsuficiente(disponible, cantidad)
        MonedaLedger.objects.create(
            usuario=usuario,
            cantidad=-cantidad,
            tipo=MonedaLedger.Tipo.CANJE,
            fecha=fecha,
            version_regla=version_regla_vigente(fecha),
        )
    return disponible - cantidad


def anular_ganadas_antes_de(usuario, corte: date, hoy: date | None = None) -> int:
    """Anula las monedas ganadas antes de `corte` que sigan sin gastar.

    Es la parte de monedas del retroactivo denegado. Como ganar es posible sin
    póliza pero gastar no, lo ganado antes de verificar nunca se pudo canjear:
    lo que queda de esos lotes es todo lo que hay que anular. Un descuento
    consume primero el lote que vence antes, y los lotes más viejos vencen
    antes, así que la fila negativa se come justo esos lotes.
    Idempotente: una segunda corrida no encuentra nada que anular.
    """
    hoy = hoy or hoy_guatemala()
    with transaction.atomic():
        _bloquear(usuario)
        expirar_vencidas(usuario, hoy)
        restante = sum(
            lote.restante for lote in lotes_vivos(usuario) if lote.fecha < corte
        )
        if restante:
            MonedaLedger.objects.create(
                usuario=usuario,
                cantidad=-restante,
                tipo=MonedaLedger.Tipo.AJUSTE_MANUAL,
                fecha=hoy,
                version_regla=version_regla_vigente(hoy),
            )
    return restante
