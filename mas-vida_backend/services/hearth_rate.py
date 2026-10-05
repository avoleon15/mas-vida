from datetime import date, datetime

from services.points import AGE_BONUS_MINIMUM, AGE_BONUS_POINTS

GAP_MAX = 15
H_INTENSITY = 0.70
MID_INTENSITY = 0.60
MIN_SESSION_DURATION_MINUTES = 30
POINTS_30_MIN_60_PERCENT = 50
POINTS_30_MIN_70_PERCENT = 100
POINTS_60_MIN_60_PERCENT = 100
POINTS_90_MIN_60_PERCENT = 150

def fcm(edad: int) -> int:
    if edad < 0:
        raise ValueError('La edad no puede ser negativa')
    fcm = 219 - edad 
    return fcm

def calc_MID_INTENSITY(fcm: int) -> float:
    mid_int = fcm * MID_INTENSITY 
    return mid_int

def calc_H_INTENSITY(fcm: int) -> float:
    h_int = fcm * H_INTENSITY
    return h_int

def calculate_session_intensity_tier(sesion: dict, edad: int) -> int:
    frecuencia_maxima = fcm(edad)
    umbral_medio = calc_MID_INTENSITY(frecuencia_maxima)
    umbral_alto = calc_H_INTENSITY(frecuencia_maxima)
    duracion = sesion["duracion_min"]
    frecuencia_promedio = sesion["fc_promedio"]

    if duracion < MIN_SESSION_DURATION_MINUTES:
        return 0
    if frecuencia_promedio < umbral_medio:
        return 0
    if duracion >= 90:
        return POINTS_90_MIN_60_PERCENT
    if duracion >= 60:
        return POINTS_60_MIN_60_PERCENT
    if frecuencia_promedio >= umbral_alto:
        return POINTS_30_MIN_70_PERCENT
    return POINTS_30_MIN_60_PERCENT

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

def detectar_tramos_continuos(muestras_ordenadas: list[dict], umbral_bpm: float,) -> list[list[dict]]:
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
        if hueco <= GAP_MAX:
            tramo_actual.append(muestra)
        else:
            tramos.append(tramo_actual)
            tramo_actual = [muestra]
    if tramo_actual:
        tramos.append(tramo_actual)
    return tramos

def calcular_duracion_tramo(tramo: list[dict]) -> float:
    inicio = parse_fecha(tramo[0]["inicio"])
    fin = parse_fecha(tramo[-1]["fin"])
    return (fin - inicio).total_seconds() / 60

def filtrar_tramos_validos(tramos: list[list[dict]]) -> list[list[dict]]:
    return [
        tramo
        for tramo in tramos
        if calcular_duracion_tramo(tramo) >= MIN_SESSION_DURATION_MINUTES
        ]

def convertir_tramo_a_sesion_inferida(tramo: list[dict]) -> dict:
    bpms = [muestra["bpm"] for muestra in tramo]

    return {
        "inicio": tramo[0]["inicio"],
        "fin": tramo[-1]["fin"],
        "duracion_min": calcular_duracion_tramo(tramo),
        "fc_promedio": sum(bpms) / len(bpms),
        "fc_maxima": max(bpms),
        "inferida": True,
    }

def convertir_tramos_a_sesiones_inferidas(
    tramos_validos: list[list[dict]],
) -> list[dict]:
    return [
        convertir_tramo_a_sesion_inferida(tramo)
        for tramo in tramos_validos
    ]

def sesiones_se_traslapan(sesion_a: dict, sesion_b: dict) -> bool:
    inicio_a = parse_fecha(sesion_a["inicio"])
    fin_a = parse_fecha(sesion_a["fin"])

    inicio_b = parse_fecha(sesion_b["inicio"])
    fin_b = parse_fecha(sesion_b["fin"])

    return inicio_a < fin_b and inicio_b < fin_a

def filtrar_sesiones_inferidas_sin_traslape(sesiones_inferidas: list[dict], sesiones_reales: list[dict],) -> list[dict]:
    return [
        sesion_inferida
        for sesion_inferida in sesiones_inferidas
        if not any(
            sesiones_se_traslapan(sesion_inferida, sesion_real)
            for sesion_real in sesiones_reales
        )
    ]

def calculate_daily_intensity_points(sesiones: list[dict], edad: int,) -> int:
    puntos_intensidad = max(
        (
            calculate_session_intensity_tier(sesion, edad)
            for sesion in sesiones
        ),
        default=0,
    )
    if puntos_intensidad > 0 and edad >= AGE_BONUS_MINIMUM:
        puntos_intensidad += AGE_BONUS_POINTS
    return puntos_intensidad

def calculate_intensity_from_heart_rate(
    frecuencia_cardiaca: list[dict],
    sesiones_reales: list[dict],
    edad: int,
) -> int:
    frecuencia_maxima = fcm(edad)
    umbral_medio = calc_MID_INTENSITY(frecuencia_maxima)
    muestras_ordenadas = ordenar_muestras_bpm(frecuencia_cardiaca)
    tramos = detectar_tramos_continuos(
        muestras_ordenadas,
        umbral_medio,
    )
    tramos_validos = filtrar_tramos_validos(tramos)

    sesiones_inferidas = convertir_tramos_a_sesiones_inferidas(
        tramos_validos
    )
    sesiones_inferidas = filtrar_sesiones_inferidas_sin_traslape(
        sesiones_inferidas,
        sesiones_reales,
    )
    sesiones_del_dia = sesiones_reales + sesiones_inferidas
    return calculate_daily_intensity_points(sesiones_del_dia, edad)

def minutos_por_zona(ritmo_por_dispositivo: dict, edad: int) -> dict | None:
    """Minutos del día en cada zona de ritmo cardíaco, o None si no hubo ritmo.

    Zonas según la misma FCmáx de los puntos (219 − edad): ligero por debajo del
    60 %, moderado del 60 % al 70 % (sin llegar) e intenso del 70 % hacia arriba.
    El reposo cuenta como ligero.

    Una lectura representa el tiempo hasta que empieza la siguiente, sin pasar de
    GAP_MAX minutos (un hueco más largo es tiempo sin dato, igual que al armar
    las sesiones inferidas). La última lectura vale lo que dura ella misma.

    Dos dispositivos que registran a la vez no se suman: se usa el que cubre más
    minutos del día (el empate lo resuelve la clave del dispositivo, para que el
    resultado sea siempre el mismo).
    """
    candidatos = []
    for clave, muestras in ritmo_por_dispositivo.items():
        if not muestras:
            continue
        ordenadas = ordenar_muestras_bpm(muestras)
        minutos = _minutos_de_cada_lectura(ordenadas)
        candidatos.append((sum(minutos), clave, ordenadas, minutos))
    if not candidatos:
        return None

    _, _, ordenadas, minutos = max(candidatos, key=lambda c: (c[0], c[1]))
    umbral_medio = calc_MID_INTENSITY(fcm(edad))
    umbral_alto = calc_H_INTENSITY(fcm(edad))
    zonas = {"minutos_ligero": 0.0, "minutos_moderado": 0.0, "minutos_intenso": 0.0}
    for muestra, duracion in zip(ordenadas, minutos):
        if muestra["bpm"] >= umbral_alto:
            zonas["minutos_intenso"] += duracion
        elif muestra["bpm"] >= umbral_medio:
            zonas["minutos_moderado"] += duracion
        else:
            zonas["minutos_ligero"] += duracion
    return {zona: round(total) for zona, total in zonas.items()}


def _minutos_de_cada_lectura(ordenadas: list[dict]) -> list[float]:
    minutos = []
    for i, muestra in enumerate(ordenadas):
        inicio = parse_fecha(muestra["inicio"])
        if i + 1 < len(ordenadas):
            hasta = (parse_fecha(ordenadas[i + 1]["inicio"]) - inicio).total_seconds() / 60
        else:
            hasta = (parse_fecha(muestra["fin"]) - inicio).total_seconds() / 60
        minutos.append(min(max(hasta, 0), GAP_MAX))
    return minutos


def calculate_age(birth_date: date, scoring_date: date) -> int:
    if scoring_date < birth_date:
        raise ValueError("La fecha de puntuación no puede ser anterior al nacimiento")

    return (
        scoring_date.year
        - birth_date.year
        - (
            (scoring_date.month, scoring_date.day)
            < (birth_date.month, birth_date.day)
        )
    )


    