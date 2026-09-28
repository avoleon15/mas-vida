BUNDLE_A_TIPO = {
    "com.garmin.connect": "reloj",
    "com.whoop": "reloj",
    "com.huami": "reloj",
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


def tipo_dispositiv(muestra: dict)-> str:
    modelo = (muestra.get("dispositivo_modelo" or "")).strip().lower()
    bundle = (muestra.get("fuente_bundle" or "")).strip().lower()
    fabricante = (muestra.get("dispositivo_fabricante" or "")).strip().lower()
