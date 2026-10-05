from django.urls import path
from .views import LoginView, logout, perfil, registro


urlpatterns = [
    path("registro", registro, name="registro"),
    path("login", LoginView.as_view(), name="login"),
    path("logout", logout, name="logout"),
    path("perfil", perfil, name="perfil"),
]