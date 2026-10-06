from django.contrib import admin, messages
from django.utils import timezone

from services import polizas

from .models import CorreccionDeNacimiento, PolizaVinculada, RegistroAseguradora


class CorreccionDeNacimientoInline(admin.TabularInline):
    """El historial de correcciones de la póliza: solo se ve, lo escribe save_model."""

    model = CorreccionDeNacimiento
    extra = 0
    can_delete = False
    readonly_fields = ("fecha_anterior", "fecha_nueva", "desde", "creada_en")

    def has_add_permission(self, request, obj=None):
        return False


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
        "retroactivo", "corte_retroactivo",
    )
    inlines = [CorreccionDeNacimientoInline]
    actions = ["verificar_polizas", "rechazar_polizas"]

    def save_model(self, request, obj, form, change):
        if not change:
            obj.estado_verificacion = polizas.PENDIENTE

        # Cambiar la fecha confirmada de una póliza ya VERIFICADA es una corrección de
        # la aseguradora: vale desde hoy y no le quita nada a la persona (el veredicto
        # del retroactivo ya está tomado). Queda registrada.
        correccion = None
        if change and obj.estado_verificacion == polizas.VERIFICADA and obj.birth_date_confirmada:
            anterior = (
                PolizaVinculada.objects.filter(pk=obj.pk).values_list("birth_date_confirmada", flat=True).first()
            )
            if anterior and anterior != obj.birth_date_confirmada:
                correccion = (anterior, obj.birth_date_confirmada)

        super().save_model(request, obj, form, change)

        if correccion is not None:
            CorreccionDeNacimiento.objects.create(
                poliza=obj, fecha_anterior=correccion[0], fecha_nueva=correccion[1],
                desde=timezone.localdate(),
            )
            self.message_user(
                request,
                f"{obj.policy_number}: la fecha de nacimiento cambió de {correccion[0]} a "
                f"{correccion[1]}. Vale desde hoy; lo anterior se queda con la fecha de entonces "
                "y no se le quita nada.",
                messages.WARNING,
            )

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
            elif resultado == "tolerado":
                self.message_user(
                    request,
                    f"{poliza.policy_number}: verificada. La fecha de nacimiento difiere "
                    "poco y no le da ventaja: se toma como error y el histórico se conserva.",
                    messages.SUCCESS,
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
