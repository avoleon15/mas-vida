from django.urls import path
from rest_framework.authtoken.views import obtain_auth_token

from .views import perfil, registro


urlpatterns = [
    path("registro", registro, name="registro"),
    path("login", obtain_auth_token, name="login"),
    path("perfil", perfil, name="perfil"),
]