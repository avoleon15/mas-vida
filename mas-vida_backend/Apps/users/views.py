from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from services import identidad_externa, login_social
from .serializers import LoginSocialSerializer, RegistroSerializer


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


def _error(codigo, mensaje, estado):
    return Response({"error": codigo, "mensaje": mensaje}, status=estado)


def _login_social(request, proveedor):
    """Cuerpo: `{credencial, birth_date?, nonce?}`. Ver contrato, "Inicio de sesión con Google y Apple".

    La credencial es tan sensible como una contraseña: no se escribe en logs ni
    en los mensajes de error.
    """
    serializer = LoginSocialSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    datos = serializer.validated_data

    try:
        identidad = identidad_externa.verificar(
            proveedor, datos["credencial"], datos.get("nonce"),
        )
    except identidad_externa.ProveedorNoConfigurado:
        return _error(
            "proveedor_no_configurado",
            "Este inicio de sesión todavía no está disponible.",
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    except identidad_externa.ProveedorNoDisponible:
        return _error(
            "proveedor_no_disponible",
            "No pudimos comunicarnos para verificar tu cuenta. Inténtalo de nuevo en un momento.",
            status.HTTP_503_SERVICE_UNAVAILABLE,
        )
    except identidad_externa.CredencialInvalida:
        return _error(
            "credencial_invalida",
            "No pudimos verificar tu cuenta. Inténtalo de nuevo.",
            status.HTTP_401_UNAUTHORIZED,
        )

    try:
        user, nuevo = login_social.entrar(identidad, datos.get("birth_date"))
    except login_social.CorreoYaRegistrado as ya:
        return Response(
            {
                "error": "correo_ya_registrado",
                "metodo": ya.metodo,
                "mensaje": "Ese correo ya tiene una cuenta. Entra con el método que usaste al crearla.",
            },
            status=status.HTTP_409_CONFLICT,
        )
    except login_social.FaltaFechaNacimiento:
        return _error(
            "falta_fecha_nacimiento",
            "Necesitamos tu fecha de nacimiento para crear tu cuenta.",
            status.HTTP_422_UNPROCESSABLE_ENTITY,
        )
    except login_social.CuentaInactiva:
        return _error(
            "cuenta_inactiva", "Esta cuenta está desactivada.", status.HTTP_403_FORBIDDEN,
        )

    token, _ = Token.objects.get_or_create(user=user)
    return Response(
        {
            "token": token.key,
            "nuevo": nuevo,
            "username": user.username,
            "usuario_id": user.usuario.usuario_id,
        },
        status=status.HTTP_201_CREATED if nuevo else status.HTTP_200_OK,
    )


# Sin autenticación: un token viejo en el encabezado no debe impedir iniciar sesión.
@api_view(["POST"])
@authentication_classes([])
@permission_classes([AllowAny])
def login_google(request):
    return _login_social(request, identidad_externa.GOOGLE)


@api_view(["POST"])
@authentication_classes([])
@permission_classes([AllowAny])
def login_apple(request):
    return _login_social(request, identidad_externa.APPLE)
