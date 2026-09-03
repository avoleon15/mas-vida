from django.db import transaction
from django.db.utils import DataError, IntegrityError
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from Apps.users.models import Usuario
from .models import Muestra, MuestraBPM, Sesion


@api_view(['POST'])
def sync(request):
    payload = request.data
    print("PAYLOAD RECIBIDO:", payload)
    usuario_id = payload.get('usuario_id')


    try:
        usuario = Usuario.objects.get(usuario_id=usuario_id)
    except Usuario.DoesNotExist:
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

        nueva_frecuencia_cardiaca = [
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
                Muestra.objects.bulk_create(nuevos_pasos, ignore_conflicts=True)

            if nuevas_sesiones:
                Sesion.objects.bulk_create(nuevas_sesiones, ignore_conflicts=True)

            if nueva_frecuencia_cardiaca:
                MuestraBPM.objects.bulk_create(nueva_frecuencia_cardiaca, ignore_conflicts=True)
    except (DataError, IntegrityError):
        return Response(
            {'mensaje': 'Datos inválidos en el payload'},
            status=status.HTTP_400_BAD_REQUEST
        )

    return Response(
        {
            "fecha": payload.get("fecha"),
            "puntos_pasos": 0,
            "puntos_intensidad": 0,
            "puntos_dia": 0,
            "tope_diario_aplicado": False,
            "puntos_ano": 0,
            "tope_anual_aplicado": False,
            "nivel": 0
        },
        status=status.HTTP_200_OK
    )