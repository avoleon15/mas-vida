from django.urls import path

from .views import ligas_view, salir_view, unirse_view

urlpatterns = [
    path("ligas", ligas_view, name="ligas"),
    path("ligas/unirse", unirse_view, name="ligas-unirse"),
    path("ligas/<str:liga_id>/salir", salir_view, name="ligas-salir"),
]
