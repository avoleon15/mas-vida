from django.contrib import admin
from .models import (
    LigaMensual,
    TramoPremio,
    DesgloseLigaMensual,
    LigaAmigos,
    MiembroLigaAmigos,
)

admin.site.register([
    LigaMensual,
    TramoPremio,
    DesgloseLigaMensual,
    LigaAmigos,
    MiembroLigaAmigos,
])