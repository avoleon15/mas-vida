from django.contrib import admin

from .models import PolizaVinculada, RegistroAseguradora


@admin.register(PolizaVinculada)
class PolizaVinculadaAdmin(admin.ModelAdmin):
    # Vista de lista para revisar y cambiar el estado de verificación de
    # varias pólizas de un vistazo (pendiente, verificada, rechazada).
    list_display = (
        "usuario",
        "insurer",
        "policy_number",
        "estado_verificacion",
        "motivo_rechazo",
        "fecha_vinculacion",
    )
    list_filter = ("estado_verificacion", "insurer")
    search_fields = ("policy_number", "usuario__usuario_id")
    readonly_fields = ("fecha_vinculacion",)


@admin.register(RegistroAseguradora)
class RegistroAseguradoraAdmin(admin.ModelAdmin):
    # Documento simulado de la aseguradora (solo para pruebas). Se carga con
    # el comando cargar_registro_aseguradora; acá se puede revisar.
    list_display = (
        "numero_poliza",
        "aseguradora",
        "nombre",
        "apellido",
        "estado",
        "vigencia_inicio",
        "vigencia_fin",
    )
    list_filter = ("estado", "aseguradora")
    search_fields = ("numero_poliza", "nombre", "apellido")
