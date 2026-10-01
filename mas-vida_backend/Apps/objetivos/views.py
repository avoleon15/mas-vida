from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from Apps.users.models import Usuario
from services import goals
from services.tiempo import hoy


@api_view(["GET"])
def retos_estado(request):
    """Objetivo de la semana en curso, avance del usuario y season (demo 1).

    El path conserva "retos" aunque el concepto ya se llama objetivo semanal
    (contrato técnico, puntos abiertos). El objetivo es el mismo para todos;
    `progreso` es del usuario que pregunta. `historial_seasons` va vacío en el
    demo: mientras no haya progresión no hay objetivo máximo que registrar.
    """
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(
            {"mensaje": "El usuario autenticado no tiene un perfil asociado."},
            status=status.HTTP_403_FORBIDDEN,
        )

    fecha = hoy()
    objetivo = goals.objetivo_de_la_semana(fecha)
    avance = goals.progreso(usuario, objetivo)
    season = goals.season_de(fecha)

    return Response({
        "objetivo": {
            "meta_pasos": objetivo.meta_pasos,
            "meta_workouts": objetivo.meta_workouts,
            "monedas_al_cumplir": goals.MONEDAS_POR_OBJETIVO,
            "fecha_inicio": objetivo.fecha_inicio.isoformat(),
            "fecha_fin": objetivo.fecha_fin.isoformat(),
        },
        "progreso": {
            "pasos_acumulados": avance.pasos,
            "workouts_acumulados": avance.workouts,
            "cumplido": avance.cumplido,
        },
        "season": {
            "numero": season.numero,
            "fecha_cierre": season.fecha_fin.isoformat(),
        },
        "historial_seasons": [],
    })
