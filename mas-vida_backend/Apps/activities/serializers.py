"""Validación del payload de POST /api/v1/sync (JSON #1 del contrato).

Dos niveles, como se acordó para la plausibilidad en v1:
- Errores de estructura (campo faltante, tipo o fecha mal formados): el sync
  completo se rechaza con 400 diciendo exactamente qué campo falló.
- Valores físicamente imposibles (p. ej. 40.000 pasos en una muestra): esa
  muestra se descarta y el resto se acepta. Son los mismos topes que ya
  impone la base de datos, pero se aplican antes para que el resultado no
  dependa del motor (en SQLite un CHECK roto se ignora en silencio; en
  Postgres tumba el INSERT completo).
"""
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from rest_framework import serializers

MAX_PASOS_POR_MUESTRA = 30_000
BPM_MIN, BPM_MAX = 30, 230
MAX_MINUTOS_SESION = 24 * 60


class _MuestraBase(serializers.Serializer):
    external_id = serializers.CharField(max_length=255)
    inicio = serializers.DateTimeField()
    fin = serializers.DateTimeField()
    fuente_bundle = serializers.CharField(max_length=255)
    fuente_nombre = serializers.CharField(max_length=255)
    fuente_version = serializers.CharField(
        max_length=255, required=False, allow_null=True, allow_blank=True
    )
    # HKDevice: null cuando la muestra no trae dispositivo, nunca cadena vacía.
    dispositivo_nombre = serializers.CharField(
        max_length=255, required=False, allow_null=True, allow_blank=True
    )
    dispositivo_modelo = serializers.CharField(
        max_length=255, required=False, allow_null=True, allow_blank=True
    )
    dispositivo_fabricante = serializers.CharField(
        max_length=255, required=False, allow_null=True, allow_blank=True
    )

    def validate(self, data):
        for campo in (
            "fuente_version",
            "dispositivo_nombre",
            "dispositivo_modelo",
            "dispositivo_fabricante",
        ):
            if not data.get(campo):
                data[campo] = None
        return data


class MuestraPasosSerializer(_MuestraBase):
    cantidad = serializers.IntegerField(min_value=0)


class MuestraBPMSerializer(_MuestraBase):
    bpm = serializers.IntegerField(min_value=0)


class SesionSerializer(_MuestraBase):
    duracion_min = serializers.IntegerField(min_value=0)
    # null es válido: un reloj puede detectar el workout sin clasificarlo.
    tipo_actividad = serializers.CharField(
        max_length=255, required=False, allow_null=True, allow_blank=True
    )
    fc_promedio = serializers.IntegerField(min_value=0)
    fc_maxima = serializers.IntegerField(min_value=0)

    def validate(self, data):
        data = super().validate(data)
        if not data.get("tipo_actividad"):
            data["tipo_actividad"] = None
        return data


def pasos_plausible(m) -> bool:
    return 0 <= m["cantidad"] <= MAX_PASOS_POR_MUESTRA and m["fin"] >= m["inicio"]


def bpm_plausible(m) -> bool:
    return BPM_MIN <= m["bpm"] <= BPM_MAX and m["fin"] >= m["inicio"]


def sesion_sin_ritmo_cardiaco(s) -> bool:
    """Workout sin reloj: Swift manda fc_promedio y fc_maxima en 0.

    No es un dato roto, es un entrenamiento que no se puede contar: un workout
    necesita ritmo cardíaco (regla del producto, 1 oct 2026). Se descarta, pero
    se cuenta aparte de los datos imposibles para poder distinguirlos en el log.
    """
    return s["fc_promedio"] == 0 and s["fc_maxima"] == 0


def sesion_plausible(s) -> bool:
    return (
        s["fin"] >= s["inicio"]
        and 0 < s["duracion_min"] <= MAX_MINUTOS_SESION
        and BPM_MIN <= s["fc_promedio"] <= BPM_MAX
        and BPM_MIN <= s["fc_maxima"] <= BPM_MAX
        and s["fc_maxima"] >= s["fc_promedio"]
    )


LISTAS = (
    ("pasos", MuestraPasosSerializer, pasos_plausible),
    ("sesiones", SesionSerializer, sesion_plausible),
    ("frecuencia_cardiaca", MuestraBPMSerializer, bpm_plausible),
)


class SyncSerializer(serializers.Serializer):
    # usuario_id del contrato se ignora a propósito: la identidad sale del token.
    fecha = serializers.DateField()
    zona_horaria = serializers.CharField(max_length=64)
    sincronizado_en = serializers.DateTimeField()
    app_version = serializers.CharField(max_length=32)
    pasos = serializers.ListField(
        child=serializers.DictField(), required=False, default=list
    )
    sesiones = serializers.ListField(
        child=serializers.DictField(), required=False, default=list
    )
    frecuencia_cardiaca = serializers.ListField(
        child=serializers.DictField(), required=False, default=list
    )

    def validate_zona_horaria(self, value):
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError):
            raise serializers.ValidationError("Zona horaria IANA inválida.")
        return value

    def validate(self, attrs):
        errores = {}
        descartadas = {}

        descartadas["sesiones_sin_ritmo_cardiaco"] = 0

        for nombre, clase, es_plausible in LISTAS:
            validas = []
            descartadas[nombre] = 0
            for i, crudo in enumerate(attrs[nombre]):
                item = clase(data=crudo)
                if not item.is_valid():
                    errores[f"{nombre}[{i}]"] = item.errors
                elif es_plausible(item.validated_data):
                    validas.append(item.validated_data)
                elif nombre == "sesiones" and sesion_sin_ritmo_cardiaco(item.validated_data):
                    descartadas["sesiones_sin_ritmo_cardiaco"] += 1
                else:
                    descartadas[nombre] += 1
            attrs[nombre] = validas

        if errores:
            raise serializers.ValidationError(errores)

        attrs["descartadas"] = descartadas
        return attrs
