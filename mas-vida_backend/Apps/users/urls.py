from django.urls import path
from .views import LoginView, perfil, registro


urlpatterns = [
    path("registro", registro, name="registro"),
    path("login", LoginView.as_view(), name="login"),
    path("perfil", perfil, name="perfil"),
]