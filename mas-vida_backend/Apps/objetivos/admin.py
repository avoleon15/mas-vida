from django.contrib import admin
from .models import (
    ObjetivoSemanal,
    CumplimientoSemanal,
    Season,
    ProgresoObjetivoUsuario,
    MetaPorPasosObjetivo,
)

admin.site.register([
    ObjetivoSemanal,
    CumplimientoSemanal,
    Season,
    ProgresoObjetivoUsuario,
    MetaPorPasosObjetivo,
])