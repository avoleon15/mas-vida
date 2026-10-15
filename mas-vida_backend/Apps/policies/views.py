from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from Apps.users.models import Usuario
from services import cashback as servicio_cashback, intentos, polizas
from services.policy_verification import VERIFICADA, verificar_con_datos
from .models import PolizaVinculada
from .serializers import VincularPolizaSerializer


# Nunca se registran el número de póliza, la fecha de nacimiento ni nada del
# cuerpo: son datos personales.

SIN_PERFIL = {"mensaje": "El usuario autenticado no tiene un perfil asociado."}


def _fecha(valor):
    return valor.isoformat() if valor else None


def _dejar_rechazada(poliza, motivo):
    """Rechazada y sin ninguno de los datos que entregó la aseguradora."""
    poliza.estado_verificacion = PolizaVinculada.EstadoVerificacion.RECHAZADA
    poliza.motivo_rechazo = motivo
    poliza.birth_date_confirmada = None
    poliza.policy_start_date = None
    poliza.nombre = poliza.apellido = poliza.plan = None
    poliza.prima_anual_gtq = None
    poliza.fecha_renovacion = None
    poliza.retroactivo = ""
    poliza.corte_retroactivo = None
    poliza.save()


def _estado(poliza):
    """Lo que ve la app. `verificada` es el gate: pendiente y rechazada no desbloquean nada."""
    if poliza is None:
        return {
            "estado": "sin_poliza",
            "verificada": False,
            "motivo_rechazo": None,
            "poliza": None,
        }
    return {
        "estado": poliza.estado_verificacion,
        "verificada": poliza.estado_verificacion == polizas.VERIFICADA,
        "motivo_rechazo": poliza.motivo_rechazo,
        "poliza": {
            "policy_number": poliza.policy_number,
            "insurer": poliza.insurer,
            # Lo de abajo es nulo hasta que la aseguradora confirma la póliza.
            "policy_start_date": _fecha(poliza.policy_start_date),
            "nombre": poliza.nombre,
            "apellido": poliza.apellido,
            "plan": poliza.plan,
            # Texto con dos decimales: es dinero y no debe pasar por un float.
            "prima_anual_gtq": (
                f"{poliza.prima_anual_gtq:.2f}" if poliza.prima_anual_gtq is not None else None
            ),
            # La próxima: si la que dio la aseguradora ya pasó, la póliza se
            # renovó y la siguiente es un año después.
            "fecha_renovacion": _fecha(polizas.proxima_renovacion(poliza.fecha_renovacion)),
        },
    }


@api_view(["GET"])
def estado_poliza(request):
    """Estado de la póliza del usuario autenticado (`sin_poliza` si no hay)."""
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)
    return Response(_estado(polizas.poliza_de(usuario)))


@api_view(["GET"])
def cashback(request):
    """Cashback en quetzales del año de póliza en curso (para Mi Plan)."""
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)
    return Response(servicio_cashback.resumen(usuario))


@api_view(["POST"])
def vincular(request):
    """Vincula y verifica la póliza del usuario autenticado.

    La póliza queda `verificada` o `rechazada` (con su motivo). Una póliza solo
    puede estar verificada en una cuenta (4 oct 2026; las pólizas familiares se
    hablan con las aseguradoras): la segunda queda `rechazada` con el motivo
    `poliza_en_otra_cuenta`.

    Al verificar se aplica la regla de retroactividad (services.polizas): si
    la fecha de nacimiento del registro no coincide con la que confirma la
    aseguradora, lo ganado antes de hoy se anula con constancia en el ledger.
    """
    serializer = VincularPolizaSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    datos = serializer.validated_data

    # El usuario sale del token, nunca del cuerpo de la petición.
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)

    # Sin límite se podría adivinar la fecha de nacimiento del titular de una
    # póliza probando días. Solo cuentan los rechazos; ver services/intentos.py.
    clave_poliza = intentos.clave_de_poliza(datos["insurer"], datos["policy_number"])
    clave_cuenta = str(usuario.pk)
    try:
        intentos.revisar(intentos.VINCULAR_POLIZA, clave_poliza)
        intentos.revisar(intentos.VINCULAR_CUENTA, clave_cuenta)
    except intentos.Bloqueado as bloqueado:
        return bloqueado.respuesta()

    with transaction.atomic():
        poliza, _ = PolizaVinculada.objects.select_for_update().get_or_create(
            usuario=usuario,
            defaults={
                "policy_number": datos["policy_number"].strip(),
                "insurer": datos["insurer"].strip(),
            },
        )

        # Cambiar una póliza ya verificada le quitaría el acceso a cashback y
        # canje sin aviso; por eso solo se permite desde pendiente o rechazada.
        if poliza.estado_verificacion == PolizaVinculada.EstadoVerificacion.VERIFICADA:
            return Response(
                {"mensaje": "Ya tienes una póliza verificada."},
                status=status.HTTP_409_CONFLICT,
            )

        resultado = verificar_con_datos(
            datos["policy_number"], datos["insurer"], datos["birth_date"]
        )

        poliza.policy_number = datos["policy_number"].strip()
        poliza.insurer = datos["insurer"].strip()
        poliza.fecha_verificacion = timezone.now()
        if resultado.estado == VERIFICADA:
            poliza.motivo_rechazo = None
            poliza.birth_date_confirmada = resultado.datos.fecha_nacimiento
            poliza.policy_start_date = resultado.datos.vigencia_inicio
            poliza.nombre = resultado.datos.nombre
            poliza.apellido = resultado.datos.apellido
            poliza.plan = resultado.datos.plan
            poliza.prima_anual_gtq = resultado.datos.prima_anual_gtq
            poliza.fecha_renovacion = resultado.datos.vigencia_fin
            # El número oficial de la aseguradora, no como lo escribió el
            # usuario (por ejemplo "pol-100001" en minúsculas).
            poliza.policy_number = resultado.datos.numero_poliza
            poliza.estado_verificacion = PolizaVinculada.EstadoVerificacion.PENDIENTE
            poliza.save()
            try:
                # Pasa a verificada y aplica o deniega el retroactivo.
                polizas.verificar(poliza)
            except polizas.PolizaEnOtraCuenta:
                # Ya es de otra cuenta verificada: no se verifica ni se toca el historial.
                _dejar_rechazada(poliza, polizas.MOTIVO_POLIZA_EN_OTRA_CUENTA)
        else:
            _dejar_rechazada(poliza, resultado.motivo)

    # Solo cuentan los rechazos de la aseguradora: quien ya acertó con el número y
    # la fecha, y se topa con que la póliza es de otra cuenta, no está adivinando.
    if (
        poliza.estado_verificacion == PolizaVinculada.EstadoVerificacion.RECHAZADA
        and poliza.motivo_rechazo != polizas.MOTIVO_POLIZA_EN_OTRA_CUENTA
    ):
        intentos.registrar(intentos.VINCULAR_POLIZA, clave_poliza)
        intentos.registrar(intentos.VINCULAR_CUENTA, clave_cuenta)

    return Response(
        {
            "estado_verificacion": poliza.estado_verificacion,
            "motivo_rechazo": poliza.motivo_rechazo,
        },
        status=status.HTTP_200_OK,
    )
