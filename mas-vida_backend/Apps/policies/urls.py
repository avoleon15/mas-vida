from django.urls import path

from .views import estado_poliza, vincular

urlpatterns = [
    path("polizas/estado", estado_poliza, name="polizas-estado"),
    path("polizas/vincular", vincular, name="polizas-vincular"),
]
