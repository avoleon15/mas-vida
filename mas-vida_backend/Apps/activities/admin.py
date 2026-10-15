from django.contrib import admin
from .models import Muestra, Sesion, MuestraBPM, ResumenDiario

admin.site.register([Muestra, MuestraBPM, Sesion, ResumenDiario])

