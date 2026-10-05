from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from services import intentos
from services import perfil as servicio_perfil
from .models import Usuario
from .serializers import RegistroSerializer


@api_view(["POST"])
@permission_classes([AllowAny])
def registro(request):
    # Cuenta todos los intentos de esa IP, salgan bien o mal.
    ip = intentos.ip_de(request)
    try:
        intentos.revisar(intentos.REGISTRO_IP, ip)
    except intentos.Bloqueado as bloqueado:
        return bloqueado.respuesta()
    intentos.registrar(intentos.REGISTRO_IP, ip)

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


class LoginView(ObtainAuthToken):
    """Igual que el login de siempre (`200 {"token"}` o `400 non_field_errors`), con límite.

    Después de 5 contraseñas malas en un minuto desde la misma IP responde `429`,
    aunque la siguiente sea la correcta. Las que salen bien no cuentan. No lee el
    encabezado `Authorization`: un token viejo no impide iniciar sesión.
    """

    authentication_classes = ()

    def post(self, request, *args, **kwargs):
        ip = intentos.ip_de(request)
        try:
            intentos.revisar(intentos.LOGIN_IP, ip)
        except intentos.Bloqueado as bloqueado:
            return bloqueado.respuesta()
        try:
            return super().post(request, *args, **kwargs)
        except ValidationError:
            intentos.registrar(intentos.LOGIN_IP, ip)
            raise


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
