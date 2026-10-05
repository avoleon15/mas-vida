from django.urls import path
from .views import LoginView, logout, logout_todos, perfil, registro


urlpatterns = [
    path("registro", registro, name="registro"),
    path("login", LoginView.as_view(), name="login"),
    path("logout", logout, name="logout"),
    path("logout/todos", logout_todos, name="logout-todos"),
    path("perfil", perfil, name="perfil"),
]