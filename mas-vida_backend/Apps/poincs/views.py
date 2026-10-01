from django.shortcuts import render
from datetime import date
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from Apps.users.models import Usuario
from .models import Ledger

# El chequeo médico está fuera de v1 y no es actividad del día.
TIPOS_DE_ACTIVIDAD = (
    Ledger.TipoLedger.PASOS,
    Ledger.TipoLedger.INTENSIDAD,
    Ledger.TipoLedger.AJUSTE_MANUAL,
    Ledger.TipoLedger.RETROACTIVO_DENEGADO,
)

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

    # Un día puede tener varias filas (pasos, intensidad y, si un dato llegó
    # tarde, un ajuste). Los puntos acreditados son la suma de todas; los
    # brutos y el tope son los de la fila más reciente, que refleja el
    # cálculo vigente del día.
    movimientos = (
         Ledger.objects
         .filter(usuario=usuario, tipo__in=TIPOS_DE_ACTIVIDAD)
         .select_related("version_regla")
         .order_by('-fecha', 'id')
    )

    if fecha_desde:
         movimientos = movimientos.filter(fecha__gte=fecha_desde)
    if fecha_hasta:
         movimientos = movimientos.filter(fecha__lte=fecha_hasta)

    por_dia = {}
    for movimiento in movimientos:
         dia = por_dia.setdefault(movimiento.fecha, {"acreditados": 0})
         dia["acreditados"] += movimiento.puntos
         dia["ultima"] = movimiento

    historial_usuario = []
    for fecha, dia in por_dia.items():
         ultima = dia["ultima"]
         # Las filas anteriores a la migración 0002 tienen estos campos en
         # null: se leen como 0 para que la suma no reviente.
         pasos = ultima.puntos_pasos or 0
         intensidad = ultima.puntos_intensidad or 0
         historial_usuario.append({
              "fecha": fecha.isoformat(),
              "puntos_pasos": pasos,
              "puntos_intensidad": intensidad,
              "puntos_brutos": pasos + intensidad,
              "puntos_dia": dia["acreditados"],
              "tope_diario_aplicado": bool(ultima.tope_diario_aplicado),
              "version_regla": ultima.version_regla.version,
         })

    return Response(
         {"historial": historial_usuario},
         status=status.HTTP_200_OK
    )

