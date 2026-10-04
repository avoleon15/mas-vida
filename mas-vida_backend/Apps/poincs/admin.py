from django.contrib import admin

from .models import Ledger, VersionRegla


class SoloAgregarAdmin(admin.ModelAdmin):
    """Admin de un ledger append-only: se puede ver y agregar, nunca editar ni borrar.

    Agregar sirve para las acreditaciones manuales (por ejemplo un chequeo
    médico o un ajuste en el demo). Una corrección es una fila nueva de signo
    contrario, no una edición.
    """

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Ledger)
class LedgerAdmin(SoloAgregarAdmin):
    list_display = ("usuario", "fecha", "tipo", "puntos", "version_regla", "creado_en")
    list_filter = ("tipo", "fecha", "version_regla")
    search_fields = ("usuario__usuario_id",)
    date_hierarchy = "fecha"


admin.site.register(VersionRegla)
