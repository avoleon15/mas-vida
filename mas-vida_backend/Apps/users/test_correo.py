"""El correo no distingue mayúsculas ni se repite entre cuentas (etapa 14, 6 oct 2026)."""
from importlib import import_module
from unittest import mock

from django.apps import apps
from django.contrib.admin.sites import site
from django.contrib.auth import get_user_model
from django.db import IntegrityError, connection, transaction
from django.forms.models import model_to_dict
from django.test import RequestFactory, TestCase
from rest_framework.test import APITestCase

from Apps.users.models import Usuario
from services import cuentas

User = get_user_model()
CLAVE = "Clave-segura-2026"


def cuenta(username, email=""):
    user = User.objects.create_user(username, email=email, password=CLAVE)
    Usuario.objects.create(user=user, usuario_id=f"id-{username}", birth_date="1990-01-01")
    return user


class RegistroTests(APITestCase):
    url = "/api/v1/registro"

    def registrar(self, username):
        return self.client.post(
            self.url, {"username": username, "password": CLAVE, "birth_date": "1990-01-01"}, format="json",
        )

    def test_el_mismo_correo_con_otras_mayusculas_ya_existe(self):
        cuenta("ana@correo.com")
        for escrito in ("Ana@Correo.com", "ANA@CORREO.COM", "ana@correo.com"):
            with self.subTest(escrito=escrito):
                r = self.registrar(escrito)
                self.assertEqual(r.status_code, 400)
                self.assertIn("username", r.json())
        self.assertEqual(User.objects.count(), 1)

    def test_tambien_al_reves_y_con_espacios(self):
        cuenta("Ana@Correo.com")
        for escrito in ("ana@correo.com", "  ana@correo.com  "):
            with self.subTest(escrito=repr(escrito)):
                self.assertEqual(self.registrar(escrito).status_code, 400)

    def test_el_correo_de_una_cuenta_de_google_o_apple_tambien_cuenta(self):
        cuenta("google-4f2a", email="Luis@Gmail.com")
        r = self.registrar("luis@gmail.com")
        self.assertEqual(r.status_code, 400)
        self.assertIn("username", r.json())

    def test_un_correo_distinto_se_registra(self):
        cuenta("ana@correo.com")
        self.assertEqual(self.registrar("ana2@correo.com").status_code, 201)
        self.assertEqual(self.registrar("beto@correo.com").status_code, 201)

    def test_se_guarda_como_lo_escribio(self):
        self.registrar("Ana@Correo.com")
        self.assertTrue(User.objects.filter(username="Ana@Correo.com").exists())

    def test_dos_registros_a_la_vez_no_dan_500(self):
        # La revisión previa no vio la cuenta (otro registro iba en camino): la base lo para.
        cuenta("ana@correo.com")
        with mock.patch("Apps.users.serializers.cuentas.correo_en_uso", return_value=False):
            r = self.registrar("ANA@correo.com")
        self.assertEqual(r.status_code, 400)
        self.assertIn("username", r.json())
        self.assertEqual(User.objects.count(), 1)


class LoginTests(APITestCase):
    url = "/api/v1/login"

    def entrar(self, username, password=CLAVE):
        return self.client.post(self.url, {"username": username, "password": password}, format="json")

    def test_entra_sin_importar_las_mayusculas(self):
        cuenta("Ana@Correo.com")
        for escrito in ("Ana@Correo.com", "ana@correo.com", "ANA@CORREO.COM", "  ana@correo.com "):
            with self.subTest(escrito=repr(escrito)):
                r = self.entrar(escrito)
                self.assertEqual(r.status_code, 200, r.content)
                self.assertEqual(r.json()["usuario_id"], "id-Ana@Correo.com")

    def test_la_contrasena_si_distingue_mayusculas(self):
        cuenta("ana@correo.com")
        self.assertEqual(self.entrar("ANA@correo.com", CLAVE.upper()).status_code, 400)

    def test_una_cuenta_que_no_existe_falla_igual_que_antes(self):
        r = self.entrar("fantasma@correo.com")
        self.assertEqual(r.status_code, 400)
        self.assertIn("non_field_errors", r.json())

    def test_los_demas_campos_siguen_siendo_obligatorios(self):
        r = self.client.post(self.url, {"username": "ana"}, format="json")
        self.assertEqual(r.status_code, 400)
        self.assertIn("password", r.json())

    def test_el_limite_de_intentos_cuenta_igual_con_otras_mayusculas(self):
        cuenta("ana@correo.com")
        for escrito in ("ana@correo.com", "ANA@correo.com", "Ana@correo.com", "aNa@correo.com", "ana@CORREO.com"):
            self.entrar(escrito, "mala-clave-1")
        self.assertEqual(self.entrar("ana@correo.com").status_code, 429)


class NombreParaEntrarTests(TestCase):
    def test_devuelve_el_username_exacto(self):
        cuenta("Ana@Correo.com")
        self.assertEqual(cuentas.nombre_para_entrar("ana@correo.com"), "Ana@Correo.com")

    def test_si_no_hay_cuenta_devuelve_lo_escrito(self):
        self.assertEqual(cuentas.nombre_para_entrar(" nadie@correo.com "), "nadie@correo.com")

    def test_un_valor_que_no_es_texto_no_rompe(self):
        self.assertIsNone(cuentas.nombre_para_entrar(None))
        self.assertEqual(cuentas.nombre_para_entrar(123), 123)


class IndiceUnicoTests(TestCase):
    def test_la_base_no_deja_dos_usernames_que_solo_difieren_en_mayusculas(self):
        cuenta("ana@correo.com")
        with self.assertRaises(IntegrityError), transaction.atomic():
            User.objects.create_user("ANA@correo.com", password=CLAVE)

    def test_ni_dos_emails(self):
        cuenta("google-1", email="luis@gmail.com")
        with self.assertRaises(IntegrityError), transaction.atomic():
            User.objects.create_user("google-2", email="LUIS@gmail.com", password=CLAVE)

    def test_varias_cuentas_sin_email_conviven(self):
        for nombre in ("a@x.com", "b@x.com", "c@x.com"):
            cuenta(nombre)
        self.assertEqual(User.objects.filter(email="").count(), 3)


class AdminDeCuentasTests(TestCase):
    """El admin de Django revisa el correo sin mayúsculas antes de guardar (antes daba un 500)."""

    def setUp(self):
        self.admin = site._registry[User]
        self.request = RequestFactory().post("/admin/")
        self.request.user = User.objects.create_superuser("root", password="x")

    def editar(self, user, **cambios):
        Form = self.admin.get_form(self.request, user)
        datos = {
            k: ("" if v is None else v)
            for k, v in model_to_dict(user, fields=list(Form.base_fields)).items()
            if k not in ("date_joined", "last_login")
        }
        datos.update({"date_joined_0": "2026-10-01", "date_joined_1": "10:00:00", "last_login_0": "", "last_login_1": ""})
        datos.update(cambios)
        return Form(data=datos, instance=user)

    def test_no_deja_cambiar_el_usuario_a_otro_que_solo_difiere_en_mayusculas(self):
        cuenta("ana@correo.com")
        form = self.editar(cuenta("beto@correo.com"), username="ANA@correo.com")
        self.assertFalse(form.is_valid())
        self.assertIn("username", form.errors)

    def test_no_deja_poner_un_email_que_ya_tiene_otra_cuenta(self):
        cuenta("google-1", email="luis@gmail.com")
        form = self.editar(cuenta("beto@correo.com"), email="LUIS@gmail.com")
        self.assertFalse(form.is_valid())
        self.assertIn("email", form.errors)

    def test_no_deja_poner_de_email_el_usuario_de_otra_cuenta(self):
        cuenta("ana@correo.com")
        form = self.editar(cuenta("beto@correo.com"), email="Ana@Correo.com")
        self.assertFalse(form.is_valid())
        self.assertIn("email", form.errors)

    def test_la_propia_cuenta_puede_cambiar_sus_mayusculas_y_guardarse(self):
        ana = cuenta("ana@correo.com")
        form = self.editar(ana, username="Ana@Correo.com", email="ana@correo.com")
        self.assertTrue(form.is_valid(), form.errors)
        form.save()
        self.assertEqual(User.objects.get(pk=ana.pk).username, "Ana@Correo.com")

    def test_crear_una_cuenta_que_solo_difiere_en_mayusculas_tampoco(self):
        cuenta("ana@correo.com")
        Form = self.admin.get_form(self.request, None)
        form = Form(data={"username": "ANA@correo.com", "password1": "Otra-clave-2026", "password2": "Otra-clave-2026"})
        self.assertFalse(form.is_valid())
        self.assertIn("username", form.errors)

    def test_crear_con_el_email_de_otra_cuenta_como_usuario_tampoco(self):
        cuenta("google-1", email="luis@gmail.com")
        Form = self.admin.get_form(self.request, None)
        form = Form(data={"username": "Luis@Gmail.com", "password1": "Otra-clave-2026", "password2": "Otra-clave-2026"})
        self.assertFalse(form.is_valid())
        self.assertIn("username", form.errors)


class PaginasDelAdminTests(TestCase):
    """Las páginas del admin de cuentas cargan y el alta funciona de punta a punta."""

    def setUp(self):
        root = User.objects.create_superuser("root", password="x")
        self.client.force_login(root)

    def test_la_pagina_de_crear_usuario_carga(self):
        self.assertEqual(self.client.get("/admin/auth/user/add/").status_code, 200)

    def test_la_pagina_de_editar_usuario_carga(self):
        ana = cuenta("ana@correo.com")
        self.assertEqual(self.client.get(f"/admin/auth/user/{ana.pk}/change/").status_code, 200)

    def test_las_paginas_de_usuarios_y_consentimientos_cargan(self):
        from services import baja, consentimiento
        ana = Usuario.objects.get(user=cuenta("ana@correo.com"))
        beto = Usuario.objects.get(user=cuenta("beto@correo.com"))
        consentimiento.aceptar(ana, consentimiento.VERSION_VIGENTE)
        baja.dar_de_baja(beto)
        for url in (
            "/admin/users/usuario/",
            "/admin/users/usuario/?dado_de_baja_en__isempty=0",
            "/admin/users/usuario/?dado_de_baja_en__isempty=1",
            f"/admin/users/usuario/{beto.pk}/change/",
            "/admin/users/consentimiento/",
            f"/admin/users/consentimiento/{ana.consentimiento_set.get().pk}/change/",
        ):
            with self.subTest(url=url):
                self.assertEqual(self.client.get(url).status_code, 200)

    def test_crear_desde_el_admin_funciona_y_rechaza_el_repetido_sin_500(self):
        datos = {"username": "nueva@correo.com", "password1": "Otra-clave-2026", "password2": "Otra-clave-2026", "usable_password": "true"}
        r = self.client.post("/admin/auth/user/add/", datos)
        self.assertEqual(r.status_code, 302)
        self.assertTrue(User.objects.filter(username="nueva@correo.com").exists())
        r = self.client.post("/admin/auth/user/add/", {**datos, "username": "NUEVA@correo.com"})
        self.assertEqual(r.status_code, 200)                      # vuelve al formulario con el error
        self.assertEqual(User.objects.filter(username__iexact="nueva@correo.com").count(), 1)


class MigracionTests(TestCase):
    """Si la base ya trae cuentas repetidas, la migración se detiene y las lista."""

    def setUp(self):
        self.migracion = import_module("Apps.users.migrations.0007_correo_unico_sin_mayusculas")

    def _sin_indices(self):
        with connection.cursor() as cursor:
            cursor.execute("DROP INDEX uq_auth_user_username_lower")
            cursor.execute("DROP INDEX uq_auth_user_email_lower")

    def test_sin_repetidos_no_hace_nada(self):
        cuenta("ana@correo.com")
        cuenta("beto@correo.com")
        self.migracion.verificar_que_no_haya_repetidos(apps, None)

    def test_con_repetidos_se_detiene_y_dice_cuales(self):
        self._sin_indices()
        cuenta("ana@correo.com")
        cuenta("ANA@correo.com")
        with self.assertRaises(RuntimeError) as error:
            self.migracion.verificar_que_no_haya_repetidos(apps, None)
        self.assertIn("ana@correo.com", str(error.exception))
        self.assertIn("Resuélvelas a mano", str(error.exception))

    def test_tambien_detecta_el_email_repetido(self):
        self._sin_indices()
        cuenta("google-1", email="luis@gmail.com")
        cuenta("google-2", email="LUIS@gmail.com")
        with self.assertRaises(RuntimeError):
            self.migracion.verificar_que_no_haya_repetidos(apps, None)
