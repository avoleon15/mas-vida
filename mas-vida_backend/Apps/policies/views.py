from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import (
    api_view,
    authentication_classes,
    permission_classes,
)
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from Apps.users.models import Usuario
from services import polizas
from services.policy_verification import VERIFICADA, verificar_con_datos
from .models import PolizaVinculada
from .serializers import VincularPolizaSerializer


# Nunca se registran el número de póliza, la fecha de nacimiento ni nada del
# cuerpo: son datos personales.

SIN_PERFIL = {"mensaje": "El usuario autenticado no tiene un perfil asociado."}


def _estado(poliza):
    """Lo que ve la app. `verificada` es el gate: pendiente y rechazada no desbloquean nada."""
    if poliza is None:
        return {"estado": "sin_poliza", "verificada": False, "poliza": None}
    return {
        "estado": poliza.estado_verificacion,
        "verificada": poliza.estado_verificacion == polizas.VERIFICADA,
        "motivo_rechazo": poliza.motivo_rechazo,
        "poliza": {
            "policy_number": poliza.policy_number,
            "insurer": poliza.insurer,
            # Nulo hasta que la aseguradora confirma la póliza.
            "policy_start_date": (
                poliza.policy_start_date.isoformat()
                if poliza.policy_start_date else None
            ),
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


@api_view(["POST"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def vincular(request):
    """Vincula y verifica la póliza del usuario autenticado.

    La póliza queda `verificada` o `rechazada` (con su motivo). Una póliza sí
    puede estar vinculada a más de un usuario (pólizas familiares).

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
            # El número oficial de la aseguradora, no como lo escribió el
            # usuario (por ejemplo "pol-100001" en minúsculas).
            poliza.policy_number = resultado.datos.numero_poliza
            poliza.estado_verificacion = PolizaVinculada.EstadoVerificacion.PENDIENTE
            poliza.save()
            # Pasa a verificada y aplica o deniega el retroactivo.
            polizas.verificar(poliza)
        else:
            poliza.estado_verificacion = PolizaVinculada.EstadoVerificacion.RECHAZADA
            poliza.motivo_rechazo = resultado.motivo
            poliza.birth_date_confirmada = None
            poliza.policy_start_date = None
            poliza.save()

    return Response(
        {
            "estado_verificacion": poliza.estado_verificacion,
            "motivo_rechazo": poliza.motivo_rechazo,
        },
        status=status.HTTP_200_OK,
    )
