from rest_framework import status
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.decorators import api_view, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from services import intentos, sesiones
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
    token = sesiones.token_para(user)

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

    Después de 5 contraseñas malas en un minuto para el mismo usuario (o 30 desde la
    misma IP) responde `429`, aunque la siguiente sea la correcta. Las que salen
    bien no cuentan. No lee el encabezado `Authorization`: un token viejo no
    impide iniciar sesión.
    """

    authentication_classes = ()

    def post(self, request, *args, **kwargs):
        ip = intentos.ip_de(request)
        datos = request.data if hasattr(request.data, "get") else {}
        cuenta = intentos.clave_de_usuario(datos.get("username"))
        try:
            intentos.revisar(intentos.LOGIN_CUENTA, cuenta)
            intentos.revisar(intentos.LOGIN_IP, ip)
        except intentos.Bloqueado as bloqueado:
            return bloqueado.respuesta()
        serializer = self.serializer_class(data=request.data, context={"request": request})
        try:
            serializer.is_valid(raise_exception=True)
        except ValidationError:
            intentos.registrar(intentos.LOGIN_CUENTA, cuenta)
            intentos.registrar(intentos.LOGIN_IP, ip)
            raise
        # Un token vencido no se revive: se entrega uno nuevo (ver services/sesiones.py).
        token = sesiones.token_para(serializer.validated_data["user"])
        return Response({"token": token.key})


@api_view(["POST"])
def logout(request):
    """Cierra la sesión: borra el token. 204 sin cuerpo.

    Hay un token por cuenta y lo comparten sus dispositivos, así que cierra la
    sesión en todos. Con un token inválido o vencido responde 401, igual que el resto.
    """
    sesiones.cerrar_sesion(request.user)
    return Response(status=status.HTTP_204_NO_CONTENT)


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
