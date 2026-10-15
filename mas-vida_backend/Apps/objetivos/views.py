from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from Apps.users.models import Usuario
from services import goals, monedas, patrocinios
from services.tiempo import hoy, numero_semana_en_season

SIN_PERFIL = {"mensaje": "El usuario autenticado no tiene un perfil asociado."}


def _componente(meta, monedas_que_paga, acumulados=None, cumplido=None):
    """Un componente del objetivo (pasos o workouts) tal como lo ve la app."""
    return {
        "meta": meta,
        "monedas": monedas_que_paga,
        "acumulados": acumulados,
        "cumplido": cumplido,
    }


def _season(fecha):
    season = goals.season_de(fecha)
    semanas = ((season.fecha_fin - season.fecha_inicio).days + 1) // 7
    return {
        "numero": season.numero,
        "anio": season.anio,
        "fecha_inicio": season.fecha_inicio.isoformat(),
        "fecha_cierre": season.fecha_fin.isoformat(),
        "semanas": semanas,
        # Las monedas se reinician al cerrar la season: se avisa 7 días antes.
        "dias_para_cierre": monedas.dias_para_fin_de_season(fecha),
        "aviso_fin_de_season": monedas.aviso_fin_de_season(fecha),
    }


@api_view(["GET"])
def objetivos_estado(request):
    """Objetivo de la semana en curso y el avance del usuario en cada componente.

    Cada componente (pasos y workouts) dice su meta, cuántas monedas paga y si
    ya se cumplió; `completada` es true solo con los dos. La meta de pasos es la
    del rango de edad del usuario. `historial_seasons` va vacío en el demo.
    """
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)

    fecha = hoy()
    objetivo = goals.objetivo_de_la_semana(fecha)
    avance = goals.progreso(usuario, objetivo)

    return Response({
        "semana": {
            "numero": numero_semana_en_season(fecha),
            "fecha_inicio": objetivo.fecha_inicio.isoformat(),
            "fecha_fin": objetivo.fecha_fin.isoformat(),
        },
        "pasos": _componente(
            avance.meta_pasos_efectiva, objetivo.monedas_pasos,
            avance.pasos, avance.cumplio_pasos,
        ),
        "workouts": _componente(
            objetivo.meta_workouts, objetivo.monedas_workouts,
            avance.workouts, avance.cumplio_workouts,
        ),
        "completada": avance.completada,
        "season": _season(fecha),
        "historial_seasons": [],
    })


@api_view(["GET"])
def objetivos_semanas(request):
    """Todas las semanas de la season en curso, para la vista tipo "battle pass".

    Estado de cada una: `completada`, `parcial` (un solo componente),
    `no_cumplida`, `en_curso`, `en_revision` (el lunes, la que terminó el domingo:
    sigue en su margen de gracia hasta el cierre del martes) o `futura`. En las futuras, `acumulados` y
    `cumplido` van en null. `patrocinador` es la marca que compró esa
    semana (la misma forma que `patrocinio` de La Liga) o null si no tiene.
    """
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)

    fecha = hoy()
    semanas = goals.semanas_de_la_season(usuario, fecha)
    vendidas = patrocinios.de_semanas([s.objetivo.fecha_inicio for s in semanas])

    return Response({
        "season": _season(fecha),
        "semanas": [
            {
                "numero": semana.numero,
                "fecha_inicio": semana.objetivo.fecha_inicio.isoformat(),
                "fecha_fin": semana.objetivo.fecha_fin.isoformat(),
                "estado": semana.estado,
                "pasos": _componente(
                    semana.meta_pasos, semana.objetivo.monedas_pasos,
                    semana.pasos, semana.cumplio_pasos,
                ),
                "workouts": _componente(
                    semana.objetivo.meta_workouts, semana.objetivo.monedas_workouts,
                    semana.workouts, semana.cumplio_workouts,
                ),
                "patrocinador": patrocinios.como_json(vendidas.get(semana.objetivo.fecha_inicio)),
            }
            for semana in semanas
        ],
    })
