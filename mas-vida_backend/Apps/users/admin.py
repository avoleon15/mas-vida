from django.contrib import admin

from Apps.policies.models import PolizaVinculada
from .models import Usuario


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
