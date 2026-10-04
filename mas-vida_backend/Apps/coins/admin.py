from django.contrib import admin

from Apps.poincs.admin import SoloAgregarAdmin

from .models import Canje, MonedaLedger, Premio


@admin.register(MonedaLedger)
class MonedaLedgerAdmin(SoloAgregarAdmin):
    list_display = ("usuario", "fecha", "tipo", "cantidad", "fecha_expiracion", "version_regla", "creado_en")
    list_filter = ("tipo", "fecha", "version_regla")
    search_fields = ("usuario__usuario_id",)
    date_hierarchy = "fecha"


admin.site.register([Premio, Canje])
