from datetime import datetime

gap_max = 15
H_intensity = 0.70
Mid_intensity = 0.60

def fcm(edad: int) -> int:
    if edad < 0:
        raise ValueError('La edad no puede ser negativa')
    fcm = 219 - edad 
    return fcm

def calc_mid_intensity(fcm: int) -> float:
    mid_int = fcm * Mid_intensity 
    return mid_int

def calc_h_intensity(fcm: int) -> float:
    h_int = fcm * H_intensity
    return h_int

def ordenar_muestras_bpm(muestras: list[dict]) -> list[dict]:
    return sorted(
        muestras,
        key=lambda muestra: datetime.fromisoformat(
            muestra["inicio"].replace("Z", "+00:00")
        ),
    )

def parse_fecha(fecha: str) -> datetime:
    return datetime.fromisoformat(fecha.replace("Z", "+00:00"))

def calcular_hueco_minutos( muestra_anterior: dict, muestra_actual: dict,) -> float:
    fin_anterior = parse_fecha(muestra_anterior["fin"])
    inicio_actual = parse_fecha(muestra_actual["inicio"])
    return (inicio_actual - fin_anterior).total_seconds() / 60

def detectar_tramos_continuos(
    muestras_ordenadas: list[dict],
    umbral_bpm: float,
) -> list[list[dict]]:
    tramos = []
    tramo_actual = []

    for muestra in muestras_ordenadas:
        if muestra["bpm"] < umbral_bpm:
            if tramo_actual:
                tramos.append(tramo_actual)
                tramo_actual = []
            continue

        if not tramo_actual:
            tramo_actual = [muestra]
            continue

        hueco = calcular_hueco_minutos(tramo_actual[-1], muestra)

        if hueco <= gap_max:
            tramo_actual.append(muestra)
        else:
            tramos.append(tramo_actual)
            tramo_actual = [muestra]

    if tramo_actual:
        tramos.append(tramo_actual)

    return tramos