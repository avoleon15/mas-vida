from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from services import perfil as servicio_perfil
from .models import Usuario
from .serializers import RegistroSerializer


@api_view(["POST"])
@permission_classes([AllowAny])
def registro(request):
    serializer = RegistroSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    user = serializer.save()
    token, _ = Token.objects.get_or_create(user=user)

    return Response(
        {
            "token": token.key,
            "username": user.username,
            # Lo genera el servidor, así que el cliente lo recibe acá.
            "usuario_id": user.usuario.usuario_id,
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET"])
def perfil(request):
    """Los datos de la propia cuenta para la pantalla de Perfil."""
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(
            {"mensaje": "El usuario autenticado no tiene un perfil asociado."},
            status=status.HTTP_403_FORBIDDEN,
        )
    return Response(servicio_perfil.resumen(usuario))
