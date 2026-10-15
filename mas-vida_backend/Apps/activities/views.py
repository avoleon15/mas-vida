import logging
from datetime import date, timedelta

from django.db import transaction
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from Apps.users.models import Usuario
from services import consentimiento, daily_scoring

from .models import Muestra, MuestraBPM, ResumenDiario, Sesion
from .serializers import SyncSerializer

logger = logging.getLogger(__name__)

# Contrato técnico: un dato más viejo que esto se rechaza. Es la misma cifra
# que la cola de reintentos del cliente.
VENTANA_DIAS = 14

CAMPOS_DISPOSITIVO = (
    "fuente_bundle",
    "fuente_nombre",
    "fuente_version",
    "dispositivo_nombre",
    "dispositivo_modelo",
    "dispositivo_fabricante",
)


def _modelos(clase, usuario, items, campos):
    return [
        clase(usuario=usuario, **{campo: item[campo] for campo in campos})
        for item in items
    ]


@api_view(["POST"])
def sync(request):
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(
            {"mensaje": "El usuario autenticado no tiene un perfil asociado."},
            status=status.HTTP_403_FORBIDDEN,
        )

    # Apagado por defecto (settings.CONSENTIMIENTO_OBLIGATORIO). Antes de leer el payload:
    # sin consentimiento no se guarda ningún dato de salud.
    if consentimiento.obligatorio() and not consentimiento.vigente(usuario):
        return Response(
            {"error": "consentimiento_requerido", "version": consentimiento.VERSION_VIGENTE},
            status=status.HTTP_403_FORBIDDEN,
        )

    serializer = SyncSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    datos = serializer.validated_data
    fecha = datos["fecha"]

    hoy = timezone.localdate()
    if fecha < hoy - timedelta(days=VENTANA_DIAS):
        return Response(
            {"error": "fuera_de_ventana", "fecha": fecha.isoformat()},
            status=status.HTTP_422_UNPROCESSABLE_ENTITY,
        )
    if fecha > hoy + timedelta(days=1):
        return Response(
            {"fecha": ["La fecha no puede ser futura."]},
            status=status.HTTP_400_BAD_REQUEST,
        )

    logger.info(
        "Sync: usuario=%s fecha=%s pasos=%d sesiones=%d bpm=%d descartadas=%s",
        usuario.pk, fecha, len(datos["pasos"]), len(datos["sesiones"]),
        len(datos["frecuencia_cardiaca"]), datos["descartadas"],
    )

    base = ("external_id", "inicio", "fin", *CAMPOS_DISPOSITIVO)
    try:
        with transaction.atomic():
            # Serializa los syncs del mismo usuario: dos POST del mismo día
            # (reintento + sync manual) no pueden asentar el ledger a la vez.
            Usuario.objects.select_for_update().get(pk=usuario.pk)

            Muestra.objects.bulk_create(
                _modelos(Muestra, usuario, datos["pasos"], (*base, "cantidad")),
                ignore_conflicts=True,
            )
            Sesion.objects.bulk_create(
                _modelos(
                    Sesion, usuario, datos["sesiones"],
                    (*base, "duracion_min", "tipo_actividad", "fc_promedio", "fc_maxima"),
                ),
                ignore_conflicts=True,
            )
            MuestraBPM.objects.bulk_create(
                _modelos(
                    MuestraBPM, usuario, datos["frecuencia_cardiaca"], (*base, "bpm")
                ),
                ignore_conflicts=True,
            )

            # El día del sync y también los demás a los que pertenecen sus muestras,
            # del más viejo al más nuevo. La respuesta es la del día del sync.
            dias = {fecha} | daily_scoring.dias_que_tocan(
                datos["pasos"], datos["sesiones"], datos["frecuencia_cardiaca"],
                desde=hoy - timedelta(days=VENTANA_DIAS), hasta=hoy,
            )
            for dia_a_recalcular in sorted(dias):
                resultado_dia = daily_scoring.calcular_dia(usuario, dia_a_recalcular)
                resultado_anual = daily_scoring.asentar(usuario, resultado_dia)
                daily_scoring.guardar_resumen(usuario, resultado_dia)
                if dia_a_recalcular == fecha:
                    dia, anual = resultado_dia, resultado_anual
    except daily_scoring.SinVersionRegla:
        logger.error("Sync sin VersionRegla vigente: fecha=%s", fecha)
        return Response(
            {"mensaje": "El servidor no tiene una versión de reglas configurada."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    return Response(
        {
            "fecha": fecha.isoformat(),
            "puntos_pasos": dia.puntos_pasos,
            "puntos_intensidad": dia.puntos_intensidad,
            "puntos_dia": dia.puntos_dia,
            "tope_diario_aplicado": dia.tope_diario_aplicado,
            "puntos_ano": anual.puntos_ano,
            "tope_anual_aplicado": anual.tope_anual_aplicado,
            "nivel": anual.nivel,
            "pasos_totales_dia": dia.pasos_totales,
        },
        status=status.HTTP_200_OK,
    )


# Un año completo (con bisiesto) es lo más que pide la vista Año de Progreso.
MAX_DIAS_RESUMEN = 366


def _fecha_param(request, nombre):
    crudo = request.query_params.get(nombre)
    if not crudo:
        raise ValueError(f"Falta el parámetro {nombre}.")
    try:
        return date.fromisoformat(crudo)
    except ValueError:
        raise ValueError(f"{nombre} debe tener formato AAAA-MM-DD.")


@api_view(["GET"])
def resumen_dashboard(request):
    """Filas de resumen diario del usuario en [desde, hasta].

    Solo devuelve los días que existen; rellenar los huecos con ceros es
    decisión de la pantalla. `workouts_dia` es null si no hubo sesión (no 0,
    para no confundir "sin actividad intensa" con "FC de cero").
    """
    try:
        usuario = request.user.usuario
    except Usuario.DoesNotExist:
        return Response(
            {"mensaje": "El usuario autenticado no tiene un perfil asociado."},
            status=status.HTTP_403_FORBIDDEN,
        )

    try:
        desde = _fecha_param(request, "desde")
        hasta = _fecha_param(request, "hasta")
    except ValueError as error:
        return Response({"mensaje": str(error)}, status=status.HTTP_400_BAD_REQUEST)

    if desde > hasta:
        return Response(
            {"mensaje": "desde no puede ser mayor a hasta."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if (hasta - desde).days >= MAX_DIAS_RESUMEN:
        return Response(
            {"mensaje": f"El rango no puede pasar de {MAX_DIAS_RESUMEN} días."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    filas = ResumenDiario.objects.filter(
        usuario=usuario, fecha__gte=desde, fecha__lte=hasta
    ).order_by("fecha")

    return Response([
        {
            "fecha": fila.fecha.isoformat(),
            "pasos_totales_dia": fila.pasos_totales_dia,
            "workouts_dia": (
                None
                if fila.workouts_cantidad is None
                else {
                    "cantidad": fila.workouts_cantidad,
                    "duracion_total_min": fila.workouts_duracion_total_min,
                    "fc_promedio": fila.workouts_fc_promedio,
                    "fc_maxima": fila.workouts_fc_maxima,
                }
            ),
            "puntos_dia": fila.puntos_dia,
            # null el día que no hubo ritmo cardíaco (no es lo mismo que 0 minutos).
            "ritmo_cardiaco": (
                None
                if fila.minutos_ligero is None
                else {
                    "minutos_ligero": fila.minutos_ligero,
                    "minutos_moderado": fila.minutos_moderado,
                    "minutos_intenso": fila.minutos_intenso,
                }
            ),
        }
        for fila in filas
    ])
