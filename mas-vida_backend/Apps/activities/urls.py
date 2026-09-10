from django.urls import path
from .views import sync

urlpatterns = [
    path('sync', sync, name='sync'),
]