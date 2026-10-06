from django.contrib import admin
from rest_framework.authtoken.models import TokenProxy

from Apps.policies.models import PolizaVinculada
from .models import IntentoFallido, Usuario

# Desde A35 las sesiones son de Knox ("Auth tokens" en el admin). Un token de DRF
# creado aquí ya no sirve para entrar, así que su sección se quita para no
# confundir. `rest_framework.authtoken` sigue instalada por sus migraciones y por el
# formulario del login; su comando `drf_create_token` tampoco sirve ya.
if admin.site.is_registered(TokenProxy):
    admin.site.unregister(TokenProxy)


class PolizaVinculadaInline(admin.StackedInline):
    """Deja cargar o editar la póliza desde la misma pantalla del Usuario.

    Las cuentas del piloto se pueden crear a mano en el admin, así que la
    póliza se ingresa acá en vez de en una pantalla aparte.
    """

    model = PolizaVinculada
    # Es un OneToOne: como máximo una póliza por usuario, y ninguna es válido
    # (cuenta base).
    max_num = 1
    extra = 0
    # El estado NO se edita a mano, ni siquiera desde acá: cambiarlo directo se
    # saltaría los efectos de verificar (retroactividad). Se cambia solo con las
    # acciones de la pantalla de Pólizas. fecha_vinculacion es automática.
    readonly_fields = (
        "estado_verificacion",
        "motivo_rechazo",
        "fecha_vinculacion",
        "fecha_verificacion",
    )


@admin.register(Usuario)
class UsuarioAdmin(admin.ModelAdmin):
    list_display = ("usuario_id", "user", "birth_date", "tiene_poliza_verificada")
    # Trae user y poliza en la misma consulta de la lista. Sin esto, la columna
    # "Póliza verificada" hace una consulta extra por cada fila (N+1).
    list_select_related = ("user", "poliza")
    inlines = [PolizaVinculadaInline]

    @admin.display(boolean=True, description="Póliza verificada")
    def tiene_poliza_verificada(self, usuario):
        # Solo "verificada" cuenta como póliza; "pendiente" se trata igual que
        # no tener ninguna.
        poliza = getattr(usuario, "poliza", None)
        return (
            poliza is not None
            and poliza.estado_verificacion
            == PolizaVinculada.EstadoVerificacion.VERIFICADA
        )


@admin.register(IntentoFallido)
class IntentoFallidoAdmin(admin.ModelAdmin):
    """Solo lectura: lo escribe el servidor al limitar intentos."""

    list_display = ("tipo", "clave", "creado_en")
    list_filter = ("tipo",)
    ordering = ("-creado_en",)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
