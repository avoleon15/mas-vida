from django.contrib import admin
from .models import (
    ObjetivoSemanal,
    CumplimientoSemanal,
    MetaPasosPorEdad,
    Season,
    ProgresoObjetivoUsuario,
    MetaPorPasosObjetivo,
)


@admin.register(ObjetivoSemanal)
class ObjetivoSemanalAdmin(admin.ModelAdmin):
    list_display = (
        "fecha_inicio", "fecha_fin", "meta_workouts", "monedas_pasos", "monedas_workouts",
    )
    ordering = ("-fecha_inicio",)


@admin.register(MetaPasosPorEdad)
class MetaPasosPorEdadAdmin(admin.ModelAdmin):
    list_display = ("edad_desde", "meta_pasos")


@admin.register(CumplimientoSemanal)
class CumplimientoSemanalAdmin(admin.ModelAdmin):
    list_display = (
        "usuario", "objetivo_semanal", "pasos_semanales", "meta_pasos", "cumplio_pasos",
        "workouts_acumulados", "cumplio_workouts", "cumplido", "evaluado_en",
    )
    list_filter = ("cumplido", "cumplio_pasos", "cumplio_workouts")


admin.site.register([
    Season,
    ProgresoObjetivoUsuario,
    MetaPorPasosObjetivo,
])
