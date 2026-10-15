from django.urls import path
from .views import resumen_dashboard, sync

urlpatterns = [
    path('sync', sync, name='sync'),
    path('dashboard/resumen', resumen_dashboard, name='dashboard_resumen'),
]