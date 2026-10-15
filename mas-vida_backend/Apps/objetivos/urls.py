from django.urls import path

from .views import objetivos_estado, objetivos_semanas

# Antes "retos/estado": se renombró (3 oct 2026) junto con el cambio de forma
# de la respuesta, antes de que la app lo consumiera.
urlpatterns = [
    path("objetivos/estado", objetivos_estado, name="objetivos_estado"),
    path("objetivos/semanas", objetivos_semanas, name="objetivos_semanas"),
]
