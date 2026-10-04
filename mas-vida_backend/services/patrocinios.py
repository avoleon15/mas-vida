"""Patrocinios: semanas y meses de La Liga vendidos a una marca, y premios destacados.

Reglas (contrato-tecnico.md, "Patrocinios"):
- Es el MISMO ciclo, no uno aparte: el cupón de la marca se gana ADEMÁS de las
  monedas, nunca en lugar de ellas.
- Semana: el cupón lo gana quien COMPLETA la semana (los dos objetivos).
- La Liga: el cupón lo ganan los mismos que ganan monedas (el podio, con al
  menos 1 punto).
- Un cupón ganado es un premio: hace falta póliza verificada al momento del
  cierre. Sin ella no se gana, igual que no se puede canjear.
- Un patrocinio da un solo cupón por persona, aunque el cierre corra dos veces.
- Solo cuentan los patrocinios `activo`. Sin patrocinio no se dibuja nada.
"""
from datetime import date

from Apps.coins.models import Canje, Patrocinio
from services import polizas, premios

MESES = (
    "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
    "agosto", "septiembre", "octubre", "noviembre", "diciembre",
)


def _activos(tipo):
    return Patrocinio.objects.filter(tipo=tipo, activo=True).select_related("premio")


def de_semanas(lunes: list[date]) -> dict[date, Patrocinio]:
    """Los patrocinios de esas semanas, por lunes."""
    return {p.desde: p for p in _activos(Patrocinio.Tipo.SEMANA).filter(desde__in=lunes)}


def de_semana(lunes: date) -> Patrocinio | None:
    return de_semanas([lunes]).get(lunes)


def de_liga(mes: date) -> Patrocinio | None:
    """El patrocinio de La Liga del mes que arranca el día `mes` (día 1)."""
    return _activos(Patrocinio.Tipo.LIGA).filter(desde=mes).first()


def destacados(hoy: date) -> set[int]:
    """Los ids de los premios que compraron visibilidad hoy."""
    return set(
        _activos(Patrocinio.Tipo.DESTACADO)
        .filter(desde__lte=hoy, hasta__gte=hoy)
        .values_list("premio_id", flat=True)
    )


def como_json(patrocinio: Patrocinio | None) -> dict | None:
    """Lo que lee la app (`Patrocinio.desdeJson` en Dart); null si no hay marca."""
    if patrocinio is None:
        return None
    premio = patrocinio.premio
    return {
        # El mismo id del comercio en el catálogo de Premios.
        "id": str(premio.pk),
        "marca": premio.comercio_aliado,
        "logo": premio.foto,
        "fondo": premio.fondo or None,
        "acento": patrocinio.acento or None,
        "cupon": patrocinio.cupon,
        "fotos": list(patrocinio.fotos),
    }


def _gana_cupon(usuario) -> bool:
    return polizas.tiene_poliza_verificada(usuario)


def premiar_semana(usuario, patrocinio: Patrocinio, numero_semana: int, ahora=None) -> Canje | None:
    """Cupón de la semana patrocinada para quien la completó. None si no aplica."""
    if not _gana_cupon(usuario):
        return None
    return premios.ganar_cupon(
        usuario, patrocinio, Canje.Origen.SEMANA, f"Semana {numero_semana}", ahora,
    )


def premiar_liga(usuario, patrocinio: Patrocinio, mes: date, ahora=None) -> Canje | None:
    """Cupón de La Liga patrocinada para quien subió al podio. None si no aplica."""
    if not _gana_cupon(usuario):
        return None
    return premios.ganar_cupon(
        usuario, patrocinio, Canje.Origen.LIGA, f"La Liga de {MESES[mes.month - 1]}", ahora,
    )
