from django.contrib import admin

from .models import (
    DesgloseLigaMensual,
    LigaAmigos,
    LigaMensual,
    MiembroLigaAmigos,
    PremioPodioLiga,
    TramoPremio,
)


@admin.register(PremioPodioLiga)
class PremioPodioLigaAdmin(admin.ModelAdmin):
    list_display = ("puesto", "monedas")
    list_editable = ("monedas",)


@admin.register(LigaMensual)
class LigaMensualAdmin(admin.ModelAdmin):
    list_display = ("mes", "total_participantes", "cerrada_en")


@admin.register(DesgloseLigaMensual)
class DesgloseLigaMensualAdmin(admin.ModelAdmin):
    list_display = ("liga_mensual", "posicion_final", "usuario", "puntos_mes", "pasos_acumulados_mes", "workouts_acumulados_mes", "monedas")
    list_filter = ("liga_mensual",)
    ordering = ("-liga_mensual__mes", "posicion_final")


@admin.register(LigaAmigos)
class LigaAmigosAdmin(admin.ModelAdmin):
    list_display = ("nombre", "codigo_invitacion", "creador_usuario", "mes")
    search_fields = ("nombre", "codigo_invitacion")


@admin.register(MiembroLigaAmigos)
class MiembroLigaAmigosAdmin(admin.ModelAdmin):
    list_display = ("liga_amigos", "usuario", "fecha_union")


# Del modelo viejo (premios por percentil): sin uso desde el 3 oct 2026.
admin.site.register(TramoPremio)
