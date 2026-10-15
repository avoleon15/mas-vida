from django import forms
from django.contrib import admin
from django.contrib.auth import get_user_model
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.forms import AdminUserCreationForm, UserChangeForm
from rest_framework.authtoken.models import TokenProxy

from Apps.policies.models import PolizaVinculada
from services import cuentas
from .models import Consentimiento, IntentoFallido, Usuario

User = get_user_model()

# Desde A35 las sesiones son de Knox ("Auth tokens" en el admin). Un token de DRF
# creado aquí ya no sirve para entrar, así que su sección se quita para no
# confundir. `rest_framework.authtoken` sigue instalada por sus migraciones y por el
# formulario del login; su comando `drf_create_token` tampoco sirve ya.
if admin.site.is_registered(TokenProxy):
    admin.site.unregister(TokenProxy)


class PolizaVinculadaInline(admin.StackedInline):
    """Deja cargar o editar la póliza desde la misma pantalla del Usuario.

    Las cuentas del piloto se pueden crear a mano en el admin, así que la
    póliza se ingresa acá en vez de en una pantalla aparte.
    """

    model = PolizaVinculada
    # Es un OneToOne: como máximo una póliza por usuario, y ninguna es válido
    # (cuenta base).
    max_num = 1
    extra = 0
    # El estado NO se edita a mano, ni siquiera desde acá: cambiarlo directo se
    # saltaría los efectos de verificar (retroactividad). Se cambia solo con las
    # acciones de la pantalla de Pólizas. fecha_vinculacion es automática.
    readonly_fields = (
        "estado_verificacion",
        "motivo_rechazo",
        "fecha_vinculacion",
        "fecha_verificacion",
    )


def _correo_libre(form, campo, valor):
    """El índice único de la base (users/0007) no distingue mayúsculas; el formulario
    del admin tampoco tiene que hacerlo, o guardar daría un error 500."""
    if valor and cuentas.correo_en_uso(valor, excluir_pk=form.instance.pk):
        raise forms.ValidationError("Ya hay otra cuenta con ese correo (sin importar las mayúsculas).")
    return valor


class CambioDeUsuarioForm(UserChangeForm):
    def clean_username(self):
        return _correo_libre(self, "username", self.cleaned_data.get("username"))

    def clean_email(self):
        return _correo_libre(self, "email", self.cleaned_data.get("email"))


class AltaDeUsuarioForm(AdminUserCreationForm):
    def clean_username(self):
        return _correo_libre(self, "username", super().clean_username())


if admin.site.is_registered(User):
    admin.site.unregister(User)


@admin.register(User)
class UsuarioDeAccesoAdmin(UserAdmin):
    """El admin de cuentas de Django, con el correo revisado sin mayúsculas."""

    form = CambioDeUsuarioForm
    add_form = AltaDeUsuarioForm


@admin.register(Usuario)
class UsuarioAdmin(admin.ModelAdmin):
    list_display = ("usuario_id", "user", "birth_date", "tiene_poliza_verificada", "dado_de_baja_en")
    list_filter = (("dado_de_baja_en", admin.EmptyFieldListFilter),)
    readonly_fields = ("dado_de_baja_en",)
    # Trae user y poliza en la misma consulta de la lista. Sin esto, la columna
    # "Póliza verificada" hace una consulta extra por cada fila (N+1).
    list_select_related = ("user", "poliza")
    inlines = [PolizaVinculadaInline]

    @admin.display(boolean=True, description="Póliza verificada")
    def tiene_poliza_verificada(self, usuario):
        # Solo "verificada" cuenta como póliza; "pendiente" se trata igual que
        # no tener ninguna.
        poliza = getattr(usuario, "poliza", None)
        return (
            poliza is not None
            and poliza.estado_verificacion
            == PolizaVinculada.EstadoVerificacion.VERIFICADA
        )


@admin.register(Consentimiento)
class ConsentimientoAdmin(admin.ModelAdmin):
    """Solo lectura: lo escribe la persona desde la app (aceptar y revocar)."""

    list_display = ("usuario", "version", "aceptado_en", "revocado_en")
    list_filter = ("version",)
    list_select_related = ("usuario",)
    readonly_fields = ("usuario", "version", "aceptado_en", "revocado_en")

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(IntentoFallido)
class IntentoFallidoAdmin(admin.ModelAdmin):
    """Solo lectura: lo escribe el servidor al limitar intentos."""

    list_display = ("tipo", "clave", "creado_en")
    list_filter = ("tipo",)
    ordering = ("-creado_en",)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
