from django.urls import path

from .views import (
    canjear_premio, catalogo, mis_cupones, monedas_del_periodo, patrocinios_vigentes, saldo_monedas,
)

urlpatterns = [
    path("monedas/saldo", saldo_monedas, name="monedas-saldo"),
    path("monedas/periodo", monedas_del_periodo, name="monedas-periodo"),
    path("premios", catalogo, name="premios-catalogo"),
    path("premios/<int:premio_id>/canjear", canjear_premio, name="premios-canjear"),
    path("cupones", mis_cupones, name="cupones"),
    path("patrocinios", patrocinios_vigentes, name="patrocinios"),
]
