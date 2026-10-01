from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from Apps.users.models import Usuario
from services import polizas

from .serializers import VincularPolizaSerializer


def _usuario(request):
    try:
        return request.user.usuario
    except Usuario.DoesNotExist:
        return None


def _estado(poliza):
    """Lo que ve la app. `verificada` es el gate: pendiente y rechazada no desbloquean nada."""
    if poliza is None:
        return {"estado": "sin_poliza", "verificada": False, "poliza": None}
    return {
        "estado": poliza.estado_verificacion,
        "verificada": poliza.estado_verificacion == polizas.VERIFICADA,
        "poliza": {
            "policy_number": poliza.policy_number,
            "insurer": poliza.insurer,
            "policy_start_date": poliza.policy_start_date.isoformat(),
        },
    }


@api_view(["GET"])
def estado_poliza(request):
    usuario = _usuario(request)
    if usuario is None:
        return Response(
            {"mensaje": "El usuario autenticado no tiene un perfil asociado."},
            status=status.HTTP_403_FORBIDDEN,
        )
    return Response(_estado(polizas.poliza_de(usuario)))


@api_view(["POST"])
def vincular_poliza(request):
    usuario = _usuario(request)
    if usuario is None:
        return Response(
            {"mensaje": "El usuario autenticado no tiene un perfil asociado."},
            status=status.HTTP_403_FORBIDDEN,
        )

    serializer = VincularPolizaSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    datos = serializer.validated_data

    try:
        poliza = polizas.vincular(
            usuario,
            datos["policy_number"].strip(),
            datos["insurer"].strip(),
            datos["policy_start_date"],
        )
    except polizas.PolizaYaVinculada:
        return Response(
            {"error": "poliza_ya_vinculada",
             "mensaje": "Ya tienes una póliza vinculada o en verificación."},
            status=status.HTTP_409_CONFLICT,
        )

    return Response(_estado(poliza), status=status.HTTP_201_CREATED)
