from django.urls import path
from .views import historial

urlpatterns = [
    path('historial', historial, name='historial'),
]
