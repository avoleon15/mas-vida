
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


def filtrar_por_dispositivo(muestras, dispositivo_ganador):
    """Devuelve solo las muestras del dispositivo seleccionado."""
    return [
        muestra
        for muestra in muestras
        if clave_dispositivo(muestra) == dispositivo_ganador
    ]

def seleccionar_dispositivo_ganador(pasos, sesiones, frecuencia_cardiaca):
    por_dispositivo = {}

    for muestra in pasos + sesiones + frecuencia_cardiaca:
        clave = clave_dispositivo(muestra)
        datos = por_dispositivo.setdefault(
            clave, {"tipo": tipo_dispositivo(muestra), "pasos": 0}
        )
        datos["pasos"] += muestra.get("cantidad", 0)  # solo las muestras de pasos traen "cantidad"

    # Jerarquía: reloj > anillo > teléfono/desconocido. Dentro del mismo nivel gana el de más pasos.
    for tipos in ({"reloj"}, {"anillo"}, {"telefono", "desconocido"}):
        candidatas = [
            (clave, datos)
            for clave, datos in por_dispositivo.items()
            if datos["tipo"] in tipos
        ]
        if candidatas:
            ganador, _ = max(candidatas, key=lambda c: c[1]["pasos"])
            return ganador

    return None