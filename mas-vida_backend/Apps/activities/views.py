import logging
from datetime import date
from django.db import transaction
from django.db.utils import DataError, IntegrityError
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from services.hearth_rate import (calculate_age, calculate_intensity_from_heart_rate,)
from .models import Muestra, MuestraBPM, Sesion
from users.models import Usuario
from services.points import (apply_daily_points_limit, calculate_daily_step_points,)
from poincs.models import Ledger, VersionRegla


logger = logging.getLogger(__name__)


@api_view(["POST"])
def sync(request):
    payload = request.data

    logger.debug("Payload recibido: %s", payload)

    usuario_id = payload.get("usuario_id")

    try:
        usuario = Usuario.objects.get(usuario_id=usuario_id)
    except Usuario.DoesNotExist:
        return Response(
            {"mensaje": "Usuario no encontrado"},
            status=status.HTTP_404_NOT_FOUND,
        )

    try:
        fecha_puntuacion = date.fromisoformat(payload["fecha"])

        edad = calculate_age(
            usuario.birth_date,
            fecha_puntuacion,
        )
    except (KeyError, TypeError, ValueError):
        return Response(
            {'mensaje': 'Usuario no encontrado'},
            status=status.HTTP_404_NOT_FOUND
        )

    pasos = payload.get("pasos", [])
    sesiones = payload.get("sesiones", [])
    frecuencia_cardiaca = payload.get("frecuencia_cardiaca", [])

    try:
        nuevos_pasos = [
            Muestra(
                usuario=usuario,
                external_id=m["external_id"],
                inicio=m["inicio"],
                fin=m["fin"],
                cantidad=m["cantidad"],
                fuente_bundle=m["fuente_bundle"],
                fuente_nombre=m["fuente_nombre"],
                fuente_version=m.get("fuente_version"),
            )
            for m in pasos
        ]

        nuevas_sesiones = [
            Sesion(
                usuario=usuario,
                external_id=s["external_id"],
                inicio=s["inicio"],
                fin=s["fin"],
                duracion_min=s["duracion_min"],
                tipo_actividad=s["tipo_actividad"],
                fc_promedio=s["fc_promedio"],
                fc_maxima=s["fc_maxima"],
                fuente_bundle=s["fuente_bundle"],
                fuente_nombre=s["fuente_nombre"],
            )
            for s in sesiones
        ]

        nuevas_muestras_bpm = [
            MuestraBPM(
                usuario=usuario,
                external_id=f["external_id"],
                inicio=f["inicio"],
                fin=f["fin"],
                bpm=f["bpm"],
                fuente_bundle=f["fuente_bundle"],
                fuente_nombre=f["fuente_nombre"],
            )
            for f in frecuencia_cardiaca
        ]
    except KeyError as e:
        return Response(
            {'mensaje': f'Campo faltante en payload: {e.args[0]}'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        with transaction.atomic():
            if nuevos_pasos:
                Muestra.objects.bulk_create(
                    nuevos_pasos,
                    ignore_conflicts=True,
                )

            if nuevas_sesiones:
                Sesion.objects.bulk_create(
                    nuevas_sesiones,
                    ignore_conflicts=True,
                )

            if nuevas_muestras_bpm:
                MuestraBPM.objects.bulk_create(
                    nuevas_muestras_bpm,
                    ignore_conflicts=True,
                )
    except (DataError, IntegrityError):
        return Response(
            {"mensaje": "Datos inválidos en el payload"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    pasos_totales_dia = sum(m["cantidad"] for m in pasos)
    puntos_pasos = calculate_daily_step_points(
        pasos_totales_dia,
        edad,
    )

    puntos_intensidad = calculate_intensity_from_heart_rate(
        frecuencia_cardiaca,
        sesiones,
        edad,
    )

    puntos_brutos = puntos_pasos + puntos_intensidad
    puntos_dia = apply_daily_points_limit(puntos_brutos)
    tope_diario_aplicado = puntos_brutos > puntos_dia

    version_regla = (
        VersionRegla.objects
        .filter(vigente_desde__lte=fecha_puntuacion)
        .order_by("-vigente_desde")
        .first()
    )

    if version_regla is None:
        return Response(
            {"mensaje": "No existe una versión de regla vigente"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    Ledger.objects.update_or_create(
        usuario=usuario,
        fecha=fecha_puntuacion,
        tipo="puntos_diarios",
        defaults={
            "puntos": puntos_dia,
            "version_regla": version_regla,
        },
    )
    return Response(
        {
            "fecha": fecha_puntuacion.isoformat(),
            "puntos_pasos": puntos_pasos,
            "puntos_intensidad": puntos_intensidad,
            "puntos_dia": puntos_dia,
            "tope_diario_aplicado": tope_diario_aplicado,
            "puntos_ano": 0,
            "tope_anual_aplicado": False,
            "nivel": 0,
            "pasos_totales_dia": pasos_totales_dia,
        },
        status=status.HTTP_200_OK,
    )