from django.urls import path

from .views import vincular

urlpatterns = [
    path("polizas/vincular", vincular, name="polizas-vincular"),
]
