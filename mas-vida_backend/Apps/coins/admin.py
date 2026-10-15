from django.contrib import admin

from Apps.poincs.admin import SoloAgregarAdmin
from services import premios

from .models import Canje, MonedaLedger, Patrocinio, Premio


@admin.register(MonedaLedger)
class MonedaLedgerAdmin(SoloAgregarAdmin):
    list_display = ("usuario", "fecha", "tipo", "cantidad", "fecha_expiracion", "version_regla", "creado_en")
    list_filter = ("tipo", "fecha", "version_regla")
    search_fields = ("usuario__usuario_id",)
    date_hierarchy = "fecha"


@admin.register(Premio)
class PremioAdmin(admin.ModelAdmin):
    list_display = ("nombre", "comercio_aliado", "categoria", "costo_monedas", "activo", "vigente_hasta")
    list_filter = ("activo", "categoria")
    search_fields = ("nombre", "comercio_aliado")
    list_editable = ("activo",)


@admin.register(Patrocinio)
class PatrocinioAdmin(admin.ModelAdmin):
    """Aquí se venden las semanas, los meses de La Liga y los premios destacados."""
    list_display = ("tipo", "desde", "hasta", "premio", "cupon", "activo")
    list_filter = ("tipo", "activo")
    search_fields = ("premio__nombre", "premio__comercio_aliado", "cupon")
    list_editable = ("activo",)
    ordering = ("-desde",)
    autocomplete_fields = ("premio",)


@admin.register(Canje)
class CanjeAdmin(admin.ModelAdmin):
    list_display = ("codigo", "usuario", "premio", "origen", "ganado_en", "estado", "fecha_canje", "fecha_expiracion_cupon", "usado_en")
    list_filter = ("estado", "origen")
    search_fields = ("codigo", "usuario__usuario_id", "premio__nombre")
    actions = ["marcar_como_usado"]

    @admin.action(description="Marcar como usado (el comercio entregó el beneficio)")
    def marcar_como_usado(self, request, queryset):
        marcados = sum(premios.marcar_usado(canje) for canje in queryset)
        self.message_user(request, f"{marcados} cupón(es) marcado(s) como usado.")
