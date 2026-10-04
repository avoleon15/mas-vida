import datetime

from django.contrib import admin
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.db.models import ProtectedError
from django.test import TestCase
from django.test.utils import CaptureQueriesContext
from django.db import connection
from django.urls import reverse
from django.utils import timezone
import uuid

from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.policies.models import PolizaVinculada
from Apps.users.admin import UsuarioAdmin
from Apps.users.models import Usuario


def crear_usuario(nombre="ana"):
    user = get_user_model().objects.create_user(nombre, f"{nombre}@example.com", "x")
    return Usuario.objects.create(
        user=user,
        usuario_id=f"id-{nombre}",
        birth_date=datetime.date(1990, 1, 1),
    )


def crear_poliza(usuario, **extra):
    datos = {
        "policy_number": "POL-1",
        "insurer": "Aseguradora A",
        "policy_start_date": datetime.date(2026, 1, 1),
    }
    datos.update(extra)
    return PolizaVinculada.objects.create(usuario=usuario, **datos)


class UsuarioTests(TestCase):
    def setUp(self):
        self.usuario = crear_usuario()
        self.user = self.usuario.user

    # --- Usuario.user es PROTECT ------------------------------------------

    def test_no_se_puede_borrar_el_user_si_tiene_usuario(self):
        # Usuario.user es PROTECT: hay que borrar primero el Usuario.
        with self.assertRaises(ProtectedError):
            self.user.delete()

    def test_se_puede_borrar_el_user_despues_de_borrar_su_usuario(self):
        self.usuario.delete()

        self.user.delete()

        self.assertFalse(get_user_model().objects.filter(username="ana").exists())

    def test_se_puede_borrar_un_user_que_no_tiene_usuario(self):
        # PROTECT solo aplica si existe el perfil; un User suelto (por ejemplo
        # un admin) se borra sin problema.
        admin_user = get_user_model().objects.create_user("suelto", "s@example.com", "x")

        admin_user.delete()

        self.assertFalse(get_user_model().objects.filter(username="suelto").exists())

    # --- Usuario ya no guarda datos de póliza -----------------------------

    def test_usuario_ya_no_guarda_datos_de_poliza(self):
        campos = {campo.name for campo in Usuario._meta.get_fields()}

        # Esos datos viven ahora en PolizaVinculada.
        self.assertTrue(
            {"policy_number", "insurer", "policy_start_date"}.isdisjoint(campos)
        )

    def test_usuario_conserva_sus_campos_propios(self):
        campos = {campo.name for campo in Usuario._meta.get_fields()}

        # birth_date se queda acá: el motor de intensidad la usa sin póliza.
        self.assertTrue({"user", "usuario_id", "birth_date"}.issubset(campos))

    def test_la_fecha_de_nacimiento_es_obligatoria(self):
        otro = get_user_model().objects.create_user("otro", "o@example.com", "x")

        with self.assertRaises(IntegrityError), transaction.atomic():
            Usuario.objects.create(user=otro, usuario_id="id-otro")


class AdminUsuariosTests(TestCase):
    """Las pantallas del admin cargan (las cuentas del piloto se crean ahí)."""

    def setUp(self):
        superusuario = get_user_model().objects.create_superuser(
            "admin", "a@example.com", "x"
        )
        self.client.force_login(superusuario)
        self.usuario = crear_usuario()

    # --- Lista de usuarios ------------------------------------------------

    def test_lista_de_usuarios(self):
        respuesta = self.client.get(reverse("admin:users_usuario_changelist"))

        self.assertEqual(respuesta.status_code, 200)

    def test_lista_de_usuarios_muestra_el_id_y_la_columna_de_poliza(self):
        respuesta = self.client.get(reverse("admin:users_usuario_changelist"))

        self.assertContains(respuesta, "id-ana")
        self.assertContains(respuesta, "Póliza verificada")

    def test_sin_sesion_el_admin_redirige_al_login(self):
        self.client.logout()

        respuesta = self.client.get(reverse("admin:users_usuario_changelist"))

        self.assertEqual(respuesta.status_code, 302)
        self.assertIn("/admin/login/", respuesta["Location"])

    # --- Edición con la póliza en línea -----------------------------------

    def test_edicion_de_usuario_muestra_la_poliza_en_linea(self):
        respuesta = self.client.get(
            reverse("admin:users_usuario_change", args=[self.usuario.pk])
        )

        self.assertEqual(respuesta.status_code, 200)
        self.assertContains(respuesta, "policy_number")

    def test_editar_un_usuario_que_no_existe_no_revienta(self):
        respuesta = self.client.get(reverse("admin:users_usuario_change", args=[9999]))

        # El admin redirige al índice con un aviso en vez de dar error 500.
        self.assertEqual(respuesta.status_code, 302)

    def test_se_crea_una_poliza_desde_el_admin_del_usuario(self):
        respuesta = self.client.post(
            reverse("admin:users_usuario_change", args=[self.usuario.pk]),
            {
                "user": self.usuario.user.pk,
                "usuario_id": "id-ana",
                "birth_date": "1990-01-01",
                "poliza-TOTAL_FORMS": "1",
                "poliza-INITIAL_FORMS": "0",
                "poliza-MIN_NUM_FORMS": "0",
                "poliza-MAX_NUM_FORMS": "1",
                "poliza-0-policy_number": "POL-77",
                "poliza-0-insurer": "Aseguradora Z",
                "poliza-0-policy_start_date": "2026-05-05",
                "poliza-0-estado_verificacion": "pendiente",
            },
        )

        self.assertEqual(respuesta.status_code, 302)
        poliza = PolizaVinculada.objects.get(usuario=self.usuario)
        self.assertEqual(poliza.policy_number, "POL-77")
        self.assertEqual(poliza.insurer, "Aseguradora Z")


class ColumnaPolizaVerificadaTests(TestCase):
    """La columna "Póliza verificada" del admin solo es verdadera si el estado
    es "verificada": pendiente y sin póliza cuentan igual."""

    def setUp(self):
        self.usuario_admin = UsuarioAdmin(Usuario, admin.site)

    def test_con_poliza_verificada_es_verdadera(self):
        usuario = crear_usuario()
        crear_poliza(usuario, estado_verificacion="verificada")

        self.assertTrue(self.usuario_admin.tiene_poliza_verificada(usuario))

    def test_con_poliza_pendiente_o_rechazada_es_falsa(self):
        for estado in ("pendiente", "rechazada"):
            usuario = crear_usuario(f"u-{estado}")
            crear_poliza(usuario, estado_verificacion=estado)

            self.assertFalse(self.usuario_admin.tiene_poliza_verificada(usuario))

    def test_sin_poliza_es_falsa(self):
        usuario = crear_usuario()

        self.assertFalse(self.usuario_admin.tiene_poliza_verificada(usuario))

    def test_la_lista_no_hace_una_consulta_por_fila(self):
        superusuario = get_user_model().objects.create_superuser(
            "admin", "a@example.com", "x"
        )
        self.client.force_login(superusuario)
        url = reverse("admin:users_usuario_changelist")
        crear_poliza(crear_usuario("u1"))

        with CaptureQueriesContext(connection) as con_uno:
            self.client.get(url)

        for i in range(2, 6):
            crear_poliza(crear_usuario(f"u{i}"))
        with CaptureQueriesContext(connection) as con_cinco:
            self.client.get(url)

        # Con 5 usuarios se hacen las mismas consultas que con 1 (list_select_related).
        self.assertEqual(len(con_cinco), len(con_uno))


class RegistroTests(APITestCase):
    url = "/api/v1/registro"
    clave = "Clave-segura-2026"

    def datos(self, **cambios):
        datos = {"username": "ana", "password": self.clave, "birth_date": "1990-01-01"}
        datos.update(cambios)
        return datos

    # --- Registro válido --------------------------------------------------

    def test_registro_valido_crea_cuenta_y_devuelve_token(self):
        respuesta = self.client.post(self.url, self.datos(), format="json")

        self.assertEqual(respuesta.status_code, 201)
        user = get_user_model().objects.get(username="ana")
        self.assertEqual(respuesta.json()["token"], Token.objects.get(user=user).key)
        self.assertEqual(respuesta.json()["username"], "ana")
        self.assertEqual(user.usuario.birth_date, datetime.date(1990, 1, 1))

    def test_el_servidor_genera_el_usuario_id(self):
        respuesta = self.client.post(self.url, self.datos(), format="json")

        usuario_id = respuesta.json()["usuario_id"]
        self.assertEqual(Usuario.objects.get(user__username="ana").usuario_id, usuario_id)
        # Es un UUID: si no lo fuera, esta llamada lanzaría ValueError.
        uuid.UUID(usuario_id)

    def test_el_usuario_id_que_manda_el_cliente_se_ignora(self):
        respuesta = self.client.post(
            self.url, self.datos(usuario_id="elegido-por-el-cliente"), format="json"
        )

        self.assertEqual(respuesta.status_code, 201)
        self.assertNotEqual(respuesta.json()["usuario_id"], "elegido-por-el-cliente")
        self.assertFalse(Usuario.objects.filter(usuario_id="elegido-por-el-cliente").exists())

    def test_dos_registros_reciben_usuario_id_distintos(self):
        primero = self.client.post(self.url, self.datos(), format="json").json()
        segundo = self.client.post(self.url, self.datos(username="beto"), format="json").json()

        self.assertNotEqual(primero["usuario_id"], segundo["usuario_id"])

    def test_la_cuenta_nueva_no_tiene_poliza(self):
        self.client.post(self.url, self.datos(), format="json")

        # Cuenta base: la póliza se vincula después, en un paso aparte.
        self.assertFalse(hasattr(Usuario.objects.get(user__username="ana"), "poliza"))

    # --- Fecha de nacimiento ----------------------------------------------

    def test_fecha_de_nacimiento_futura_se_rechaza(self):
        manana = (timezone.localdate() + datetime.timedelta(days=1)).isoformat()

        respuesta = self.client.post(self.url, self.datos(birth_date=manana), format="json")

        self.assertEqual(respuesta.status_code, 400)
        self.assertIn("birth_date", respuesta.json())

    def test_fecha_de_nacimiento_futura_no_deja_cuenta_a_medias(self):
        futura = (timezone.localdate() + datetime.timedelta(days=30)).isoformat()

        self.client.post(self.url, self.datos(birth_date=futura), format="json")

        self.assertFalse(get_user_model().objects.filter(username="ana").exists())
        self.assertEqual(Usuario.objects.count(), 0)

    def test_nacer_hoy_es_valido(self):
        hoy = timezone.localdate().isoformat()

        respuesta = self.client.post(self.url, self.datos(birth_date=hoy), format="json")

        self.assertEqual(respuesta.status_code, 201)

    def test_la_fecha_de_nacimiento_es_obligatoria(self):
        datos = self.datos()
        del datos["birth_date"]

        respuesta = self.client.post(self.url, datos, format="json")

        self.assertEqual(respuesta.status_code, 400)
        self.assertIn("birth_date", respuesta.json())

    # --- Usuario y contraseña ---------------------------------------------

    def test_usuario_repetido_se_rechaza(self):
        self.client.post(self.url, self.datos(), format="json")

        respuesta = self.client.post(self.url, self.datos(), format="json")

        self.assertEqual(respuesta.status_code, 400)
        self.assertIn("username", respuesta.json())

    def test_contrasena_debil_se_rechaza(self):
        respuesta = self.client.post(self.url, self.datos(password="12345678"), format="json")

        self.assertEqual(respuesta.status_code, 400)
        self.assertIn("password", respuesta.json())

    def test_la_contrasena_no_viaja_en_la_respuesta(self):
        respuesta = self.client.post(self.url, self.datos(), format="json")

        self.assertNotIn("password", respuesta.json())
        self.assertNotIn(self.clave, respuesta.content.decode())


class LoginYTokenTests(APITestCase):
    clave = "Clave-segura-2026"

    def setUp(self):
        self.usuario = crear_usuario()
        self.usuario.user.set_password(self.clave)
        self.usuario.user.save()

    # --- Login ------------------------------------------------------------

    def test_login_correcto_devuelve_el_token_de_la_cuenta(self):
        respuesta = self.client.post(
            "/api/v1/login", {"username": "ana", "password": self.clave}, format="json"
        )

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta.json()["token"], Token.objects.get(user=self.usuario.user).key)

    def test_login_con_contrasena_equivocada_se_rechaza(self):
        respuesta = self.client.post(
            "/api/v1/login", {"username": "ana", "password": "otra-clave"}, format="json"
        )

        self.assertEqual(respuesta.status_code, 400)
        self.assertNotIn("token", respuesta.json())

    def test_login_de_un_usuario_que_no_existe_se_rechaza(self):
        respuesta = self.client.post(
            "/api/v1/login", {"username": "fantasma", "password": self.clave}, format="json"
        )

        self.assertEqual(respuesta.status_code, 400)

    # --- Token ------------------------------------------------------------

    def test_toda_cuenta_nueva_recibe_su_token_automaticamente(self):
        # El token lo crea una señal al guardar el User, venga de donde venga
        # (registro, admin o consola).
        user = get_user_model().objects.create_user("nueva", "n@example.com", "x")

        self.assertTrue(Token.objects.filter(user=user).exists())

    def test_guardar_de_nuevo_el_user_no_duplica_el_token(self):
        self.usuario.user.first_name = "Ana"
        self.usuario.user.save()

        self.assertEqual(Token.objects.filter(user=self.usuario.user).count(), 1)

    def test_el_token_abre_los_endpoints_protegidos(self):
        token = Token.objects.get(user=self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

        respuesta = self.client.get("/api/v1/historial")

        self.assertEqual(respuesta.status_code, 200)

    def test_sin_token_los_endpoints_protegidos_dan_401(self):
        respuesta = self.client.get("/api/v1/historial")

        self.assertEqual(respuesta.status_code, 401)

    def test_un_token_inventado_da_401(self):
        self.client.credentials(HTTP_AUTHORIZATION="Token no-existe")

        respuesta = self.client.get("/api/v1/historial")

        self.assertEqual(respuesta.status_code, 401)

    def test_registro_y_login_no_piden_token(self):
        # Son la puerta de entrada: si pidieran token nadie podría obtenerlo.
        registro = self.client.post("/api/v1/registro", {}, format="json")
        login = self.client.post("/api/v1/login", {}, format="json")

        self.assertEqual(registro.status_code, 400)
        self.assertEqual(login.status_code, 400)
