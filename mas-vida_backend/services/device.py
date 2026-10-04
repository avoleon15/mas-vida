from datetime import datetime

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


def _hora_local(muestra):
    """Hora (en hora de Guatemala) en la que empieza la muestra.

    Una muestra que cruza el cambio de hora cuenta en la hora en que empieza.
    Guatemala no tiene horario de verano, así que las horas son estables.
    """
    inicio = datetime.fromisoformat(muestra["inicio"])
    return timezone.localtime(inicio).replace(minute=0, second=0, microsecond=0)


def pasos_ganadores_por_hora(pasos):
    """Muestras de pasos que cuentan: en cada hora, las del dispositivo con más pasos.

    El mismo caminar lo registran a la vez el teléfono y el reloj, así que
    dentro de una hora nunca se suman dos dispositivos (se duplicaría). Entre
    horas distintas sí se suma: un reloj que solo se usa para dormir no le
    quita al teléfono los pasos del día, y un reloj que solo se usa en el gym
    aporta justo esa hora. Un empate exacto se resuelve por la clave, solo para
    que el resultado sea siempre el mismo.
    """
    por_hora = {}
    for muestra in pasos:
        por_hora.setdefault(_hora_local(muestra), []).append(muestra)

    elegidas = []
    for hora in sorted(por_hora):
        grupos = agrupar_por_dispositivo(por_hora[hora])
        ganador = max(
            grupos,
            key=lambda clave: (sum(m["cantidad"] for m in grupos[clave]), clave),
        )
        elegidas.extend(grupos[ganador])
    return elegidas
