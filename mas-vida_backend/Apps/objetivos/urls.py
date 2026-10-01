from django.urls import path

from .views import retos_estado

urlpatterns = [
    path("retos/estado", retos_estado, name="retos_estado"),
]
