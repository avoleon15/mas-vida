from datetime import datetime, timedelta

from django.utils import timezone

BUNDLE_A_TIPO = {
    "com.garmin.connect": "reloj",
    "com.whoop": "reloj",
    "com.huami": "reloj",  # Zepp / Amazfit
    "com.fitbit": "reloj",
    "com.ouraring": "anillo",
}

FABRICANTE_A_TIPO = {
    "garmin": "reloj",
    "whoop": "reloj",
    "huami": "reloj",
    "amazfit": "reloj",
    "fitbit": "reloj",
    "oura": "anillo",
}


MODELO_APPLE_A_TIPO = {
    "iphone": "telefono",
    "watch": "reloj",
    "ipad": "telefono",
}


def _norm(valor):
    return (valor or "").strip().lower()

def tipo_dispositivo(muestra):
    """
    Deriva el tipo de dispositivo usando los datos crudos del payload.

    Devuelve: telefono, reloj, anillo o desconocido.
    """

    modelo = (muestra.get("dispositivo_modelo") or "").strip().lower()
    bundle = (muestra.get("fuente_bundle") or "").strip().lower()
    fabricante = (muestra.get("dispositivo_fabricante") or "").strip().lower()

    # 1. Para modelos Apple, el modelo identifica directamente la categoría.
    if modelo in MODELO_APPLE_A_TIPO:
        return MODELO_APPLE_A_TIPO[modelo]

    # 2. Para otros dispositivos, buscar el bundle por prefijo.
    for prefijo, tipo in BUNDLE_A_TIPO.items():
        if bundle.startswith(prefijo):
            return tipo

    # 3. Si el bundle no alcanza, usar el fabricante como respaldo.
    for nombre_fabricante, tipo in FABRICANTE_A_TIPO.items():
        if nombre_fabricante in fabricante:
            return tipo

    # 4. La vista tratará "desconocido" como teléfono para la precedencia.
    return "desconocido"

def clave_dispositivo(muestra):
    """Identifica el dispositivo que originó una muestra.

    Sin dispositivo_nombre: es nullable y partiría un mismo dispositivo en dos claves.
    """
    return (
        _norm(muestra.get("fuente_bundle")),
        _norm(muestra.get("dispositivo_modelo")),
        _norm(muestra.get("dispositivo_fabricante")),
    )


def agrupar_por_dispositivo(muestras):
    """{clave_dispositivo: [muestras]} para elegir ganador por métrica."""
    grupos = {}
    for muestra in muestras:
        grupos.setdefault(clave_dispositivo(muestra), []).append(muestra)
    return grupos


# Una muestra de más de una hora es un total que una app escribe de golpe (una
# pulsera que sube "11.000 pasos de 8:00 a 18:00"), no una lectura del momento.
UMBRAL_MUESTRA_LARGA = timedelta(hours=1)


def _inicio_de_hora(momento):
    """La hora en punto (hora de Guatemala) que contiene a `momento`."""
    return timezone.localtime(momento).replace(minute=0, second=0, microsecond=0)


def _parte_del_dia(muestra, inicio_dia, fin_dia):
    """Qué parte de una muestra cae dentro del día [inicio_dia, fin_dia).

    Devuelve (desde, hasta, cantidad, es_larga) o None si no toca el día. Una
    muestra que cruza la medianoche se reparte entre los dos días en proporción
    al tiempo que pasa en cada uno. Se calcula con el acumulado de cada borde,
    así lo que le toca a cada día suma SIEMPRE la cantidad original. Una lectura
    sin duración (fin = inicio) cuenta entera en el día en que ocurre.
    """
    inicio = datetime.fromisoformat(muestra["inicio"])
    fin = datetime.fromisoformat(muestra["fin"])
    duracion = (fin - inicio).total_seconds()
    es_larga = (fin - inicio) > UMBRAL_MUESTRA_LARGA

    if duracion <= 0:
        if inicio_dia <= inicio < fin_dia:
            return inicio, inicio, muestra["cantidad"], False
        return None

    desde, hasta = max(inicio, inicio_dia), min(fin, fin_dia)
    if hasta <= desde:
        return None
    antes = (desde - inicio).total_seconds()
    hasta_s = (hasta - inicio).total_seconds()
    cantidad = round(muestra["cantidad"] * hasta_s / duracion) - round(muestra["cantidad"] * antes / duracion)
    return desde, hasta, cantidad, es_larga


def _bloques_de_horas(partes):
    """Rangos de horas que se comparan como una sola unidad.

    Cada hora es su propio bloque, salvo las que cubre una muestra larga: esas se
    funden en un bloque (y dos muestras largas que se cruzan, en uno solo). Las
    muestras cortas, aunque crucen el cambio de hora, siguen contando en la hora
    en que empiezan: si no, encadenarían todas las horas del día en un solo
    bloque y un reloj usado solo en el gimnasio perdería su hora.
    """
    rangos = sorted(
        (_inicio_de_hora(desde), _inicio_de_hora(hasta - timedelta(microseconds=1)))
        for desde, hasta, _, es_larga in partes if es_larga
    )
    fundidos = []
    for primera, ultima in rangos:
        if fundidos and primera <= fundidos[-1][1]:       # comparten al menos una hora
            fundidos[-1] = (fundidos[-1][0], max(fundidos[-1][1], ultima))
        else:
            fundidos.append((primera, ultima))
    return fundidos


def pasos_ganadores_por_bloque(pasos, inicio_dia, fin_dia):
    """Muestras de pasos que cuentan en el día: en cada bloque, las del dispositivo con más pasos.

    El mismo caminar lo registran a la vez el teléfono y el reloj, así que dentro
    de un bloque nunca se suman dos dispositivos (se duplicaría). Un bloque es una
    hora, o varias si una muestra larga las cubre (ver `_bloques_de_horas`). Entre
    bloques distintos sí se suma: un reloj que solo se usa para dormir no le quita
    al teléfono los pasos del día, y uno que solo se usa en el gimnasio aporta
    justo esa hora. Un empate exacto se resuelve por la clave, solo para que el
    resultado sea siempre el mismo.

    Devuelve las muestras ganadoras con la `cantidad` que le toca a este día (las
    que cruzan la medianoche vienen recortadas).
    """
    partes = []
    for muestra in pasos:
        parte = _parte_del_dia(muestra, inicio_dia, fin_dia)
        if parte is not None and parte[2] > 0:
            partes.append((muestra, *parte))
    fundidos = _bloques_de_horas([p[1:] for p in partes])

    def bloque_de(desde):
        hora = _inicio_de_hora(desde)
        for primera, ultima in fundidos:
            if primera <= hora <= ultima:
                return primera
        return hora

    por_bloque = {}
    for muestra, desde, _hasta, cantidad, _larga in partes:
        recortada = {**muestra, "cantidad": cantidad}
        por_bloque.setdefault(bloque_de(desde), []).append(recortada)

    elegidas = []
    for bloque in sorted(por_bloque):
        grupos = agrupar_por_dispositivo(por_bloque[bloque])
        ganador = max(
            grupos,
            key=lambda clave: (sum(m["cantidad"] for m in grupos[clave]), clave),
        )
        elegidas.extend(grupos[ganador])
    return elegidas
