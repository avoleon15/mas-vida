from django.urls import path
from .views import (
    LoginView, baja_de_cuenta, consentimiento, consentimiento_revocar, logout, logout_todos, perfil, registro,
)


urlpatterns = [
    path("registro", registro, name="registro"),
    path("login", LoginView.as_view(), name="login"),
    path("logout", logout, name="logout"),
    path("logout/todos", logout_todos, name="logout-todos"),
    path("perfil", perfil, name="perfil"),
    path("consentimiento", consentimiento, name="consentimiento"),
    path("consentimiento/revocar", consentimiento_revocar, name="consentimiento-revocar"),
    path("cuenta/baja", baja_de_cuenta, name="cuenta-baja"),
]