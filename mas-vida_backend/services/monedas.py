"""Monedas: se ganan (objetivo semanal, La Liga), se gastan en Premios y caducan.

MonedaLedger es append-only: ganar, gastar, expirar y ajustar son filas
nuevas, nunca se edita una vieja. El saldo no se guarda en ningún lado: se
recalcula recorriendo el ledger.

Reglas (decididas el 2 oct 2026):
- Sin tope de acumulación.
- Todas las monedas caducan al cerrar la season en que se ganaron: el saldo
  vuelve a 0. Se pueden usar hasta el domingo en que termina la season,
  inclusive.

Cada ganancia es un "lote" y su vencimiento SIEMPRE se calcula de la season de
su fecha (`fin_de_season`), no de lo que haya quedado guardado en
`fecha_expiracion`: así las filas viejas, que se guardaron con 90 días,
siguen la regla nueva. Antes de leer o mover el saldo se asientan las
expiraciones pendientes. Eso resuelve solo el orden que pide el contrato al
cambiar de season: primero se reinicia el saldo y después se paga la semana
que terminó, que ya es de la season nueva porque se paga con la fecha de su
cierre, el martes 00:00 (el lunes es margen de gracia, `goals.DIAS_DE_GRACIA`).
Las seasons empiezan en lunes, así que ese martes siempre es de la season nueva.

Se ganan con o sin póliza; lo que exige póliza verificada es GASTARLAS, y eso
lo valida quien llama a `gastar`, no este módulo.
"""
from dataclasses import dataclass
from datetime import date

from django.db import transaction

from Apps.coins.models import MonedaLedger
from Apps.users.models import Usuario
from services.reglas import version_regla_vigente
from services.tiempo import hoy as hoy_guatemala
from services.tiempo import rango_season

# Se avisa que las monedas se reinician cuando faltan 7 días o menos para que
# termine la season. Reemplaza el aviso al llegar a 80, que existía por el tope.
DIAS_AVISO_FIN_SEASON = 7


def fin_de_season(fecha: date) -> date:
    """Último día (domingo) de la season de `fecha`: hasta ahí valen las monedas."""
    return rango_season(fecha)[1]


def dias_para_fin_de_season(hoy: date | None = None) -> int:
    """Días que faltan para que termine la season (0 el último domingo)."""
    hoy = hoy or hoy_guatemala()
    return (fin_de_season(hoy) - hoy).days


def aviso_fin_de_season(hoy: date | None = None) -> bool:
    """True desde 7 días antes de que termine la season: avisar del reinicio."""
    return dias_para_fin_de_season(hoy) <= DIAS_AVISO_FIN_SEASON


class SaldoInsuficiente(Exception):
    def __init__(self, saldo, costo):
        super().__init__(f"Saldo {saldo} insuficiente para {costo}")
        self.saldo = saldo
        self.costo = costo


@dataclass
class Lote:
    restante: int
    fecha: date              # día en que se ganó
    fecha_expiracion: date   # último día que se puede usar: fin de su season


@dataclass
class ResultadoAcreditacion:
    acreditadas: int
    saldo: int


def _orden_de_consumo(lote: Lote):
    return lote.fecha_expiracion


def lotes_vivos(usuario) -> list[Lote]:
    """Recorre el ledger y devuelve lo que queda de cada ganancia."""
    lotes: list[Lote] = []
    for mov in MonedaLedger.objects.filter(usuario=usuario).order_by("id"):
        if mov.cantidad > 0:
            lotes.append(Lote(mov.cantidad, mov.fecha, fin_de_season(mov.fecha)))
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
        if lote.fecha_expiracion < hoy
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
    """Suma monedas al saldo. Sin tope; caducan al cerrar la season de `fecha`."""
    if cantidad <= 0:
        raise ValueError("Solo se acreditan cantidades positivas")
    fecha = fecha or hoy_guatemala()

    with transaction.atomic():
        _bloquear(usuario)
        expirar_vencidas(usuario, fecha)
        previo = sum(lote.restante for lote in lotes_vivos(usuario))
        MonedaLedger.objects.create(
            usuario=usuario,
            cantidad=cantidad,
            tipo=tipo,
            fecha=fecha,
            fecha_expiracion=fin_de_season(fecha),
            version_regla=version_regla_vigente(fecha),
        )

    return ResultadoAcreditacion(acreditadas=cantidad, saldo=previo + cantidad)


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
