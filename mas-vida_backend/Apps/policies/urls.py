from django.urls import path

from .views import estado_poliza, vincular_poliza

urlpatterns = [
    path("poliza", estado_poliza, name="poliza"),
    path("poliza/vincular", vincular_poliza, name="poliza_vincular"),
]
