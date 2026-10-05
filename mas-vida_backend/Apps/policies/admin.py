from django.contrib import admin, messages

from services import polizas

from .models import PolizaVinculada, RegistroAseguradora


@admin.register(PolizaVinculada)
class PolizaVinculadaAdmin(admin.ModelAdmin):
    """Verificación manual del piloto: no hay integración con la aseguradora.

    El estado NO se edita a mano. Se cambia solo con las acciones de abajo,
    porque verificar tiene efectos (retroactividad) que un cambio directo
    del campo se saltaría.

    Flujo: llenar `birth_date_confirmada` con la fecha que confirmó la
    aseguradora, guardar, y correr la acción "Verificar".
    """

    list_display = (
        "usuario", "policy_number", "insurer",
        "estado_verificacion", "motivo_rechazo", "birth_date_confirmada",
        "fecha_vinculacion",
    )
    list_filter = ("estado_verificacion", "insurer")
    search_fields = ("policy_number", "usuario__usuario_id")
    readonly_fields = (
        "estado_verificacion", "motivo_rechazo", "fecha_vinculacion", "fecha_verificacion",
    )
    actions = ["verificar_polizas", "rechazar_polizas"]

    def save_model(self, request, obj, form, change):
        if not change:
            obj.estado_verificacion = polizas.PENDIENTE
        super().save_model(request, obj, form, change)

    @admin.action(description="Verificar pólizas seleccionadas")
    def verificar_polizas(self, request, queryset):
        for poliza in queryset.select_related("usuario"):
            try:
                resultado = polizas.verificar(poliza)
            except polizas.FaltaFechaConfirmada:
                self.message_user(
                    request,
                    f"{poliza.policy_number}: falta la fecha de nacimiento "
                    "confirmada por la aseguradora.",
                    messages.ERROR,
                )
                continue
            except polizas.PolizaEnOtraCuenta:
                self.message_user(
                    request,
                    f"{poliza.policy_number}: ya está verificada en otra cuenta. "
                    "Una cuenta verificada por póliza.",
                    messages.ERROR,
                )
                continue
            if resultado == "denegado":
                self.message_user(
                    request,
                    f"{poliza.policy_number}: verificada, pero la fecha de "
                    "nacimiento NO coincide. Se anuló el histórico anterior.",
                    messages.WARNING,
                )
            elif resultado == "aplicado":
                self.message_user(
                    request,
                    f"{poliza.policy_number}: verificada. El histórico se conserva.",
                    messages.SUCCESS,
                )

    @admin.action(description="Rechazar pólizas seleccionadas")
    def rechazar_polizas(self, request, queryset):
        for poliza in queryset:
            try:
                polizas.rechazar(poliza)
            except ValueError:
                self.message_user(
                    request,
                    f"{poliza.policy_number}: ya está verificada, no se rechaza.",
                    messages.ERROR,
                )


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
