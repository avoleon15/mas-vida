from django.urls import path
from rest_framework.authtoken.views import obtain_auth_token

from .views import login_apple, login_google, registro


urlpatterns = [
    path("registro", registro, name="registro"),
    path("login", obtain_auth_token, name="login"),
    path("login/google", login_google, name="login-google"),
    path("login/apple", login_apple, name="login-apple"),
]