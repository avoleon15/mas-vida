from django.urls import path

from .views import cashback, estado_poliza, vincular

urlpatterns = [
    path("polizas/estado", estado_poliza, name="polizas-estado"),
    path("cashback", cashback, name="cashback"),
    path("polizas/vincular", vincular, name="polizas-vincular"),
]
