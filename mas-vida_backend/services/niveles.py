"""Nivel anual de cashback (0 a 4). Fuente: reglas-puntaje-vivo.md sección 6.

Siempre numérico: nunca Bronze/Silver/Gold/Platinum.
"""

TOPE_ANUAL = 12_000

# (piso de puntos, nivel, % de cashback)
NIVELES = (
    (0, 0, 0),
    (2_500, 1, 5),
    (5_000, 2, 7.5),
    (10_000, 3, 10),
    (15_000, 4, 20),
)


def nivel_para(puntos_ano: int) -> int:
    nivel = 0
    for piso, numero, _ in NIVELES:
        if puntos_ano >= piso:
            nivel = numero
    return nivel
