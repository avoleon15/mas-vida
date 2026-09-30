from django.contrib import admin

from .models import PolizaVinculada


@admin.register(PolizaVinculada)
class PolizaVinculadaAdmin(admin.ModelAdmin):
    # Vista de lista para revisar y cambiar el estado de verificación de
    # varias pólizas de un vistazo (pendiente, verificada, rechazada).
    list_display = (
        "usuario",
        "insurer",
        "policy_number",
        "estado_verificacion",
        "fecha_vinculacion",
    )
    list_filter = ("estado_verificacion", "insurer")
    search_fields = ("policy_number", "usuario__usuario_id")
    readonly_fields = ("fecha_vinculacion",)
