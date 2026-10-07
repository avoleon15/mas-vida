from rest_framework import status
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.exceptions import ValidationError
from rest_framework.fields import DateTimeField
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from services import baja
from services import consentimiento as servicio_consentimiento
from services import cuentas, intentos, sesiones
from services import perfil as servicio_perfil
from .models import Usuario
from .serializers import RegistroSerializer


@api_view(["POST"])
# Como el login: un token viejo o vencido en el encabezado no impide crear la cuenta.
@authentication_classes([])
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
    datos = _sesion_nueva(user)
    datos["username"] = user.username

    return Response(datos, status=status.HTTP_201_CREATED)


def _sesion_nueva(user) -> dict:
    """Lo que recibe la app al entrar o registrarse: `token`, `expiry` y `usuario_id`.

    `expiry` es el vencimiento de hoy; cada uso lo corre (ver services/sesiones.py).
    `usuario_id` le sirve a Swift para saber si cambió la persona; es `null` en una
    cuenta sin perfil (las del admin, por ejemplo).
    """
    instancia, clave = sesiones.iniciar_sesion(user)
    try:
        usuario_id = user.usuario.usuario_id
    except Usuario.DoesNotExist:
        usuario_id = None
    return {
        "token": clave,
        "expiry": DateTimeField().to_representation(instancia.expiry),
        "usuario_id": usuario_id,
    }


class LoginView(ObtainAuthToken):
    """`200 {"token", "expiry", "usuario_id"}` o `400 non_field_errors`, con límite.

    Cada login abre una sesión nueva con su propio token (ver services/sesiones.py).

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
        # `ANA@correo.com` entra a la cuenta `Ana@correo.com`: se busca sin distinguir mayúsculas.
        entrada = dict(datos.items())
        if "username" in entrada:
            entrada["username"] = cuentas.nombre_para_entrar(entrada["username"])
        serializer = self.serializer_class(data=entrada, context={"request": request})
        try:
            serializer.is_valid(raise_exception=True)
        except ValidationError:
            intentos.registrar(intentos.LOGIN_CUENTA, cuenta)
            intentos.registrar(intentos.LOGIN_IP, ip)
            raise
        return Response(_sesion_nueva(serializer.validated_data["user"]))


@api_view(["POST"])
def logout(request):
    """Cierra la sesión de este teléfono: borra su token. 204 sin cuerpo.

    Las sesiones de los otros teléfonos de la cuenta siguen abiertas. Con un token
    inválido o vencido responde 401, igual que el resto.
    """
    sesiones.cerrar_sesion(request.auth)
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["POST"])
def logout_todos(request):
    """Cierra la sesión en todos los teléfonos de la cuenta. 204 sin cuerpo."""
    sesiones.cerrar_todas(request.user)
    return Response(status=status.HTTP_204_NO_CONTENT)


def _usuario_o_403(request):
    try:
        return request.user.usuario, None
    except Usuario.DoesNotExist:
        return None, Response(
            {"mensaje": "El usuario autenticado no tiene un perfil asociado."},
            status=status.HTTP_403_FORBIDDEN,
        )


def _estado_de_consentimiento(usuario) -> dict:
    datos = servicio_consentimiento.estado(usuario)
    for campo in ("aceptado_en", "revocado_en"):
        datos[campo] = DateTimeField().to_representation(datos[campo]) if datos[campo] else None
    return datos


@api_view(["GET", "POST"])
def consentimiento(request):
    """GET: el estado del consentimiento. POST `{"version"}`: lo acepta.

    `200` con el estado. `409 version_desactualizada` si la versión no es la vigente
    (la app debe volver a pedir el estado y mostrar el texto nuevo). Idempotente.
    """
    usuario, error = _usuario_o_403(request)
    if error:
        return error
    if request.method == "POST":
        version = request.data.get("version") if hasattr(request.data, "get") else None
        if not isinstance(version, str) or not version.strip():
            return Response({"version": ["Este campo es obligatorio."]}, status=status.HTTP_400_BAD_REQUEST)
        try:
            servicio_consentimiento.aceptar(usuario, version.strip())
        except servicio_consentimiento.VersionDesactualizada as vieja:
            return Response(
                {"error": "version_desactualizada", "version_vigente": str(vieja)},
                status=status.HTTP_409_CONFLICT,
            )
    return Response(_estado_de_consentimiento(usuario))


@api_view(["POST"])
def consentimiento_revocar(request):
    """Revoca el consentimiento. Idempotente: revocar otra vez no cambia nada. `200` con el estado."""
    usuario, error = _usuario_o_403(request)
    if error:
        return error
    servicio_consentimiento.revocar(usuario)
    return Response(_estado_de_consentimiento(usuario))


@api_view(["POST"])
def baja_de_cuenta(request):
    """Borra la cuenta: lo personal se borra y lo anónimo se conserva (services/baja.py).

    `204` sin cuerpo; desde ahí el token ya no sirve. Una cuenta con contraseña la
    tiene que confirmar (`{"password"}`): `400` si falta o no es la correcta. Las
    contraseñas malas cuentan para el mismo límite del login (5 por minuto, `429`).
    """
    usuario, error = _usuario_o_403(request)
    if error:
        return error

    user = request.user
    if user.has_usable_password():
        cuenta = intentos.clave_de_usuario(user.username)
        try:
            intentos.revisar(intentos.LOGIN_CUENTA, cuenta)
        except intentos.Bloqueado as bloqueado:
            return bloqueado.respuesta()
        password = request.data.get("password") if hasattr(request.data, "get") else None
        if password is None or password == "":
            return Response({"password": ["Este campo es obligatorio."]}, status=status.HTTP_400_BAD_REQUEST)
        if not isinstance(password, str) or not user.check_password(password):
            intentos.registrar(intentos.LOGIN_CUENTA, cuenta)
            return Response({"password": ["La contraseña no es correcta."]}, status=status.HTTP_400_BAD_REQUEST)

    baja.dar_de_baja(usuario)
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
