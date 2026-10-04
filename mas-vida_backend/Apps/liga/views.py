from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from Apps.users.models import Usuario
from services import ligas
from services.tiempo import hoy

SIN_PERFIL = {"mensaje": "El usuario autenticado no tiene un perfil asociado."}


def _usuario(request):
    try:
        return request.user.usuario
    except Usuario.DoesNotExist:
        return None


def _miembros(pks, yo, fecha):
    """La tabla del mes en curso, con la forma de `social.json` de la app.

    Se ven los puntos de cada quien; los pasos nunca salen de aquí (solo
    desempatan). El orden lo manda el servidor.
    """
    inicio, _ = ligas.rango_mes(fecha)
    filas = ligas.tabla(pks, inicio, fecha)
    tendencia = ligas.tendencias(filas, inicio, fecha)
    por_pk = ligas.usuarios(f.usuario_pk for f in filas)
    return [
        {
            "nombre": ligas.nombre_publico(por_pk[f.usuario_pk]),
            "puntos_periodo": f.puntos,
            # Con empate total, dos filas comparten el puesto.
            "posicion": f.posicion,
            "tendencia": tendencia[f.usuario_pk],
            "es_usuario": f.usuario_pk == yo.pk,
        }
        for f in filas
    ]


def _bloque_liga(fecha, premios):
    inicio, fin = ligas.rango_mes(fecha)
    return {
        "arranca": inicio.isoformat(),
        "cierra": fin.isoformat(),
        "premios_monedas": premios,
        # Hasta que exista el endpoint de patrocinios.
        "patrocinio": None,
    }


def _la_liga(yo, fecha):
    return {
        "id": ligas.ID_LA_LIGA,
        "nombre": ligas.NOMBRE_LA_LIGA,
        "tipo": "desconocidos",
        "mostrar_puntos": True,
        "ciclo": "mes",
        "miembros": _miembros(ligas.participantes_la_liga().values_list("pk", flat=True), yo, fecha),
        "liga": _bloque_liga(fecha, ligas.premios_podio()),
    }


def _tu_liga(liga, yo, fecha):
    return {
        "id": str(liga.pk),
        "nombre": liga.nombre,
        "tipo": "conocidos",
        "mostrar_puntos": True,
        "ciclo": "mes",
        "codigo": liga.codigo_invitacion,
        "creado_por_mi": liga.creador_usuario_id == yo.pk,
        "miembros": _miembros(ligas.miembros(liga), yo, fecha),
        # Tus Ligas no premian.
        "liga": _bloque_liga(fecha, []),
    }


@api_view(["GET", "POST"])
def ligas_view(request):
    """GET: La Liga (si tiene póliza verificada) y Tus Ligas del usuario.
    POST {"nombre"}: crea un grupo de Tus Ligas; quien lo crea queda adentro.
    """
    yo = _usuario(request)
    if yo is None:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)
    fecha = hoy()

    if request.method == "POST":
        try:
            liga = ligas.crear_liga(yo, request.data.get("nombre"), fecha)
        except ligas.NombreInvalido as e:
            return Response({"error": "nombre_invalido", "mensaje": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(_tu_liga(liga, yo, fecha), status=status.HTTP_201_CREATED)

    puede = ligas.puede_entrar_a_la_liga(yo)
    grupos = [_la_liga(yo, fecha)] if puede else []
    grupos += [_tu_liga(liga, yo, fecha) for liga in ligas.ligas_de(yo)]
    return Response({"puede_entrar_a_la_liga": puede, "grupos": grupos})


@api_view(["POST"])
def salir_view(request, liga_id):
    """Sale de un grupo de Tus Ligas. De La Liga no se sale (400).

    204 sin cuerpo. 404 si el grupo no existe o el usuario no está adentro.
    """
    yo = _usuario(request)
    if yo is None:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)
    try:
        ligas.salir(yo, liga_id)
    except ligas.LaLigaNoSeSale:
        return Response(
            {"error": "la_liga_no_se_sale", "mensaje": "De La Liga no se sale: es para todos."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    except ligas.NoEresMiembro:
        return Response(
            {"error": "no_eres_miembro", "mensaje": "No estás en ese grupo."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
def unirse_view(request):
    """POST {"codigo"}: entra a un grupo de Tus Ligas. Repetirlo no duplica."""
    yo = _usuario(request)
    if yo is None:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)
    fecha = hoy()
    try:
        liga = ligas.unirse(yo, request.data.get("codigo"), fecha)
    except ligas.CodigoInvalido:
        return Response(
            {"error": "codigo_invalido", "mensaje": "No encontramos un grupo con ese código."},
            status=status.HTTP_404_NOT_FOUND,
        )
    return Response(_tu_liga(liga, yo, fecha))
