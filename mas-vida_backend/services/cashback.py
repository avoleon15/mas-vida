"""Cashback en quetzales: % del nivel × prima anual (decidido 2 oct 2026).

El año es el año de póliza (services.polizas.anio_de). El backend solo calcula
y muestra el monto: se devuelve como dinero DESPUÉS del pago de la prima y lo
paga la aseguradora fuera de la app (regla regulatoria). Mientras el año
corre es una proyección con el nivel de hoy; cuando cierra, el monto del año
que terminó queda "por_pagar".

Sin póliza verificada no hay prima ni monto: se muestra el avance de la cuenta
base (año calendario) solo como referencia.
"""
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.utils import timezone

from services.niveles import nivel_para, porcentaje_de, siguiente_nivel
from services.polizas import (
    VERIFICADA,
    anio_de,
    poliza_de,
    puntos_del_anio,
    tiene_ancla_de_anio,
)

CENTAVO = Decimal("0.01")


def monto(prima: Decimal | None, nivel: int) -> Decimal | None:
    if prima is None:
        return None
    return (prima * porcentaje_de(nivel) / 100).quantize(CENTAVO, rounding=ROUND_HALF_UP)


def _dinero(valor: Decimal | None) -> str | None:
    # Texto con dos decimales: es dinero y no debe pasar por un float.
    return None if valor is None else f"{valor:.2f}"


def _anterior(usuario, poliza, inicio_actual: date) -> dict | None:
    """El año de póliza que acaba de cerrar, si dejó algo por pagar."""
    if poliza is None or poliza.policy_start_date is None:
        return None
    dia_previo = inicio_actual - timedelta(days=1)
    inicio, fin = anio_de(usuario, dia_previo)
    if inicio < poliza.policy_start_date:
        return None  # la póliza todavía no existía
    puntos = puntos_del_anio(usuario, dia_previo)
    nivel = nivel_para(puntos)
    cashback = monto(poliza.prima_anual_gtq, nivel)
    if not cashback:
        return None
    return {
        "inicio": inicio.isoformat(),
        "fin": fin.isoformat(),
        "puntos_ano": puntos,
        "nivel": nivel,
        "porcentaje": float(porcentaje_de(nivel)),
        "cashback_gtq": _dinero(cashback),
        "estado": "por_pagar",
    }


def resumen(usuario, hoy: date | None = None) -> dict:
    hoy = hoy or timezone.localdate()
    poliza = poliza_de(usuario)
    if poliza is not None and poliza.estado_verificacion != VERIFICADA:
        poliza = None  # pendiente y rechazada cuentan como sin póliza

    inicio, fin = anio_de(usuario, hoy)
    puntos = puntos_del_anio(usuario, hoy)
    nivel = nivel_para(puntos)
    prima = poliza.prima_anual_gtq if poliza else None

    proximo = siguiente_nivel(puntos)
    return {
        "con_poliza": poliza is not None,
        "anio": {
            "inicio": inicio.isoformat(),
            "fin": fin.isoformat(),
            # Sin fechas de la póliza no se inventa una renovación.
            "renovacion": (
                (fin + timedelta(days=1)).isoformat()
                if poliza and tiene_ancla_de_anio(usuario) else None
            ),
        },
        "puntos_ano": puntos,
        "nivel": nivel,
        "porcentaje": float(porcentaje_de(nivel)),
        "siguiente_nivel": None if proximo is None else {
            "nivel": proximo[0],
            "desde": proximo[1],
            "faltan": proximo[1] - puntos,
            "porcentaje": float(porcentaje_de(proximo[0])),
            "cashback_gtq": _dinero(monto(prima, proximo[0])),
        },
        "prima_anual_gtq": _dinero(prima),
        "cashback_gtq": _dinero(monto(prima, nivel)),
        "estado": "proyeccion" if poliza else "sin_poliza",
        "anterior": _anterior(usuario, poliza, inicio),
    }
