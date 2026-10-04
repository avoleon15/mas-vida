from django.urls import path

from .views import canjear_premio, catalogo, mis_cupones, saldo_monedas

urlpatterns = [
    path("monedas/saldo", saldo_monedas, name="monedas-saldo"),
    path("premios", catalogo, name="premios-catalogo"),
    path("premios/<int:premio_id>/canjear", canjear_premio, name="premios-canjear"),
    path("cupones", mis_cupones, name="cupones"),
]
