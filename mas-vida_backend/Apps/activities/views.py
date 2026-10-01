import logging
from datetime import timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from Apps.users.models import Usuario
from services import daily_scoring

from .models import Muestra, MuestraBPM, Sesion
from .serializers import SyncSerializer

logger = logging.getLogger(__name__)

# Contrato técnico: un dato más viejo que esto se rechaza. Es la misma cifra
# que la cola de reintentos del cliente.
VENTANA_DIAS = 14

CAMPOS_DISPOSITIVO = (
    "fuente_bundle",
    "fuente_nombre",
    "fuente_version",
    "dispositivo_nombre",
    "dispositivo_modelo",
    "dispositivo_fabricante",
)


def _modelos(clase, usuario, items, campos):
    return [
        clase(usuario=usuario, **{campo: item[campo] for campo in campos})
        for item in items
    ]


@api_view(["POST"])
def sync(request):
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(
            {"mensaje": "El usuario autenticado no tiene un perfil asociado."},
            status=status.HTTP_403_FORBIDDEN,
        )

    serializer = SyncSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    datos = serializer.validated_data
    fecha = datos["fecha"]

    hoy = timezone.localdate()
    if fecha < hoy - timedelta(days=VENTANA_DIAS):
        return Response(
            {"error": "fuera_de_ventana", "fecha": fecha.isoformat()},
            status=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )
    if fecha > hoy + timedelta(days=1):
        return Response(
            {"fecha": ["La fecha no puede ser futura."]},
            status=status.HTTP_400_BAD_REQUEST,
        )

    logger.info(
        "Sync: usuario=%s fecha=%s pasos=%d sesiones=%d bpm=%d descartadas=%s",
        usuario.pk, fecha, len(datos["pasos"]), len(datos["sesiones"]),
        len(datos["frecuencia_cardiaca"]), datos["descartadas"],
    )

    base = ("external_id", "inicio", "fin", *CAMPOS_DISPOSITIVO)
    try:
        with transaction.atomic():
            # Serializa los syncs del mismo usuario: dos POST del mismo día
            # (reintento + sync manual) no pueden asentar el ledger a la vez.
            Usuario.objects.select_for_update().get(pk=usuario.pk)

            Muestra.objects.bulk_create(
                _modelos(Muestra, usuario, datos["pasos"], (*base, "cantidad")),
                ignore_conflicts=True,
            )
            Sesion.objects.bulk_create(
                _modelos(
                    Sesion, usuario, datos["sesiones"],
                    (*base, "duracion_min", "tipo_actividad", "fc_promedio", "fc_maxima"),
                ),
                ignore_conflicts=True,
            )
            MuestraBPM.objects.bulk_create(
                _modelos(
                    MuestraBPM, usuario, datos["frecuencia_cardiaca"], (*base, "bpm")
                ),
                ignore_conflicts=True,
            )

            dia = daily_scoring.calcular_dia(usuario, fecha)
            anual = daily_scoring.asentar(usuario, dia)
            daily_scoring.guardar_resumen(usuario, dia)
    except daily_scoring.SinVersionRegla:
        logger.error("Sync sin VersionRegla vigente: fecha=%s", fecha)
        return Response(
            {"mensaje": "El servidor no tiene una versión de reglas configurada."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return Response(
        {
            "fecha": fecha.isoformat(),
            "puntos_pasos": dia.puntos_pasos,
            "puntos_intensidad": dia.puntos_intensidad,
            "puntos_dia": dia.puntos_dia,
            "tope_diario_aplicado": dia.tope_diario_aplicado,
            "puntos_ano": anual.puntos_ano,
            "tope_anual_aplicado": anual.tope_anual_aplicado,
            "nivel": anual.nivel,
            "pasos_totales_dia": dia.pasos_totales,
        },
        status=status.HTTP_200_OK,
    )
