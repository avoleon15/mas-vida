from django.shortcuts import render
from datetime import date
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from Apps.users.models import Usuario
from .models import Ledger

@api_view(["GET"])
def historial(request):
    fecha_desde_raw = request.query_params.get('fecha_desde')
    fecha_hasta_raw = request.query_params.get('fecha_hasta')


    try: 
        fecha_desde =(
            date.fromisoformat(fecha_desde_raw)
            if fecha_desde_raw
            else None
        )

        fecha_hasta =(
            date.fromisoformat(fecha_hasta_raw)
            if fecha_hasta_raw
            else None
        )

    except ValueError:
        return Response(
            {"mensaje": "las fechas deben usar formato date"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if fecha_desde and fecha_hasta and fecha_desde > fecha_hasta:
            return Response(
                 {'mensaje': "fecha_desde no puede ser mayor a fecha_hasta"},
                 status=status.HTTP_400_BAD_REQUEST,
            )

    try:
         usuario = Usuario.objects.get(user=request.user)
    except Usuario.DoesNotExist:
         return Response(
              {"mensaje": "El usuario no existe"},
              status=status.HTTP_404_NOT_FOUND
         )

    movimientos = (
         Ledger.objects
         .filter(usuario=usuario, tipo='puntos_diarios')
         .select_related("version_regla")
         .order_by('-fecha')
    )

    if fecha_desde:
         movimientos = movimientos.filter(fecha__gte=fecha_desde)
    if fecha_hasta:
         movimientos = movimientos.filter(fecha__lte=fecha_hasta)

    historial_usuario = [
         {
              "fecha":movimiento.fecha.isoformat(),
              # Los registros anteriores a la migracion 0002 tienen estos
              # campos en null: se leen como 0 para que la suma no reviente.
              "puntos_pasos": movimiento.puntos_pasos or 0,
              "puntos_intensidad": movimiento.puntos_intensidad or 0,
              "puntos_brutos": (
                   (movimiento.puntos_pasos or 0)
                   + (movimiento.puntos_intensidad or 0)
              ),
              "puntos_dia": movimiento.puntos,
              "tope_diario_aplicado": bool(movimiento.tope_diario_aplicado),
              "version_regla": movimiento.version_regla.version,
              }
            for movimiento in movimientos
    ]

    return Response(
         {"historial": historial_usuario},
         status=status.HTTP_200_OK
    )

