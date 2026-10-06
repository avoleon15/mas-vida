"""Sesiones con django-rest-knox (A35, 4 oct 2026).

El token vence a los 30 días sin uso con un tope de 90 días, se guarda como hash,
cada inicio de sesión tiene el suyo y se puede cerrar una sesión o todas.
"""
import secrets
from datetime import date, datetime, timedelta, timezone as utc
from unittest import mock

from django.contrib.auth import get_user_model
from django.db import DatabaseError, connection
from django.db.migrations.executor import MigrationExecutor
from django.test import TestCase, TransactionTestCase
from knox.auth import TokenAuthentication
from knox.models import AuthToken
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.test import APIClient, APITestCase

from Apps.users.autenticacion import TokenDeSesion
from Apps.users.models import Usuario
from Apps.users.pruebas import token_de
from services import sesiones

User = get_user_model()

PERFIL = "/api/v1/perfil"
LOGIN = "/api/v1/login"
LOGOUT = "/api/v1/logout"
LOGOUT_TODOS = "/api/v1/logout/todos"
REGISTRO = "/api/v1/registro"
CLAVE = "Clave-segura-2026"

ENDPOINTS_GET = (
    "/api/v1/perfil", "/api/v1/cashback", "/api/v1/polizas/estado", "/api/v1/monedas/saldo",
    "/api/v1/objetivos/estado", "/api/v1/objetivos/semanas", "/api/v1/ligas", "/api/v1/premios",
    "/api/v1/cupones", "/api/v1/historial", "/api/v1/patrocinios",
)


def en(dias=0, horas=0, minutos=0):
    """Un instante en el futuro, para mover el reloj con mock.patch."""
    return mock.patch(
        "django.utils.timezone.now",
        return_value=datetime.now(utc.utc) + timedelta(days=dias, hours=horas, minutes=minutos),
    )


def crear(nombre="ana", **extra):
    user = User.objects.create_user(f"{nombre}@correo.com", password=CLAVE, **extra)
    Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=date(1990, 5, 17))
    return user


def cliente(clave):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Token {clave}")
    return c


def entrar(nombre="ana", password=CLAVE):
    return APIClient().post(LOGIN, {"username": f"{nombre}@correo.com", "password": password}, format="json")


class VidaDelTokenTests(APITestCase):
    def setUp(self):
        self.user = crear()
        self.c = cliente(token_de(self.user))

    def test_un_token_recien_creado_funciona(self):
        self.assertEqual(self.c.get(PERFIL).status_code, 200)

    def test_sin_uso_funciona_hasta_los_30_dias_y_vence_despues(self):
        with en(dias=29, horas=23):
            self.assertEqual(self.c.get(PERFIL).status_code, 200)

    def test_pasados_30_dias_sin_uso_da_401(self):
        with en(dias=31):
            r = self.c.get(PERFIL)
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r["WWW-Authenticate"], "Token")

    def test_cada_uso_renueva_el_plazo(self):
        with en(dias=29):
            self.assertEqual(self.c.get(PERFIL).status_code, 200)       # renueva
        with en(dias=58):
            self.assertEqual(self.c.get(PERFIL).status_code, 200)       # 29 días después: sigue
        with en(dias=89):
            self.assertEqual(self.c.get(PERFIL).status_code, 401)       # 31 días sin usar

    def test_aunque_se_use_a_diario_vence_a_los_90_dias(self):
        for dia in range(1, 90):
            with en(dias=dia):
                self.assertEqual(self.c.get(PERFIL).status_code, 200, f"día {dia}")
        with en(dias=90, minutos=1):
            self.assertEqual(self.c.get(PERFIL).status_code, 401)

    def test_el_vencimiento_se_escribe_a_lo_mas_una_vez_por_hora(self):
        token = AuthToken.objects.get(user=self.user)
        with en(dias=1):
            self.c.get(PERFIL)
        token.refresh_from_db()
        primero = token.expiry
        with en(dias=1, minutos=50):
            self.c.get(PERFIL)
        token.refresh_from_db()
        self.assertEqual(token.expiry, primero)
        with en(dias=1, horas=2):
            self.c.get(PERFIL)
        token.refresh_from_db()
        self.assertGreater(token.expiry, primero)

    def test_un_token_vencido_se_borra_de_la_base(self):
        with en(dias=31):
            self.c.get(PERFIL)
        self.assertFalse(AuthToken.objects.filter(user=self.user).exists())

    def test_un_token_inexistente_da_401(self):
        self.assertEqual(cliente("no-existe").get(PERFIL).status_code, 401)

    def test_una_cuenta_desactivada_da_401(self):
        User.objects.filter(pk=self.user.pk).update(is_active=False)
        self.assertEqual(self.c.get(PERFIL).status_code, 401)

    def test_todos_los_endpoints_rechazan_un_token_vencido(self):
        with en(dias=31):
            for url in ENDPOINTS_GET:
                with self.subTest(url=url):
                    self.assertEqual(self.c.get(url).status_code, 401)
        # Knox borra el token vencido al primer intento; los POST se prueban con otro.
        c = cliente(token_de(self.user))
        with en(dias=31):
            for url in ("/api/v1/sync", "/api/v1/polizas/vincular", "/api/v1/ligas", "/api/v1/ligas/unirse",
                        "/api/v1/premios/1/canjear", LOGOUT, LOGOUT_TODOS):
                with self.subTest(url=url):
                    self.assertEqual(c.post(url, {}, format="json").status_code, 401)

    def test_los_endpoints_aceptan_el_token_vigente(self):
        for url in ENDPOINTS_GET:
            with self.subTest(url=url):
                self.assertNotEqual(self.c.get(url).status_code, 401)


class CasosQueKnoxDejaEn500Tests(APITestCase):
    """Knox 5.1 responde 500 en dos casos que DRF respondía 401 (ver autenticacion.py)."""

    def setUp(self):
        self.user = crear()
        token_de(self.user)
        self.token = AuthToken.objects.get(user=self.user)

    def test_un_encabezado_con_bytes_que_no_son_utf8_da_401(self):
        c = APIClient(raise_request_exception=False)
        c.credentials(HTTP_AUTHORIZATION="Token \xe9abc")
        r = c.get(PERFIL)
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r["WWW-Authenticate"], "Token")

    def test_si_otra_peticion_borro_el_token_mientras_se_renovaba_da_401(self):
        AuthToken.objects.filter(pk=self.token.pk).delete()      # cerró sesión en paralelo
        with en(dias=1), self.assertRaises(AuthenticationFailed):
            TokenDeSesion().renew_token(self.token)

    def test_otro_error_de_la_base_sigue_siendo_500_y_no_saca_a_nadie(self):
        # Si la base falla y el token sigue ahí, no es un 401: la app sacaría a la persona.
        falla = mock.patch.object(TokenAuthentication, "renew_token", side_effect=DatabaseError("se cayó"))
        with falla, self.assertRaises(DatabaseError):
            TokenDeSesion().renew_token(self.token)
        self.assertTrue(AuthToken.objects.filter(pk=self.token.pk).exists())

    def test_la_api_usa_esta_autenticacion(self):
        from django.conf import settings
        self.assertEqual(
            settings.REST_FRAMEWORK["DEFAULT_AUTHENTICATION_CLASSES"], ["Apps.users.autenticacion.TokenDeSesion"],
        )


class AdminDeTokensTests(TestCase):
    """En el admin solo quedan las sesiones de Knox: un token de DRF ya no sirve."""

    def setUp(self):
        self.client.force_login(User.objects.create_superuser("admin", password="x"))

    def test_no_aparece_la_seccion_de_tokens_de_drf(self):
        from django.contrib import admin
        from rest_framework.authtoken.models import TokenProxy
        self.assertFalse(admin.site.is_registered(TokenProxy))
        self.assertEqual(self.client.get("/admin/authtoken/tokenproxy/").status_code, 404)

    def test_las_sesiones_de_knox_siguen_en_el_admin(self):
        token_de(crear())
        self.assertEqual(self.client.get("/admin/knox/authtoken/").status_code, 200)


class GuardadoComoHashTests(APITestCase):
    def test_en_la_base_no_queda_la_clave_del_token(self):
        clave = entrar_y_clave()
        self.assertEqual(len(clave), 64)
        # Ningún campo guardado contiene la clave (ni siquiera como parte de un texto).
        # Knox guarda los primeros 15 caracteres para encontrar la fila: no alcanzan
        # para entrar.
        for campo, valor in AuthToken.objects.values().get().items():
            with self.subTest(campo=campo):
                self.assertNotIn(clave, str(valor))
        token = AuthToken.objects.get()
        self.assertEqual(token.token_key, clave[:15])
        self.assertEqual(len(token.digest), 128)            # SHA-512

    def test_el_token_viejo_de_drf_ya_no_sirve(self):
        from rest_framework.authtoken.models import Token
        viejo = Token.objects.create(user=crear("beto"))
        self.assertEqual(cliente(viejo.key).get(PERFIL).status_code, 401)


def entrar_y_clave():
    crear()
    return entrar().json()["token"]


class IniciarSesionTests(APITestCase):
    def setUp(self):
        self.user = crear()

    def test_responde_token_vencimiento_y_usuario_id(self):
        r = entrar()
        self.assertEqual(r.status_code, 200)
        datos = r.json()
        self.assertEqual(set(datos), {"token", "expiry", "usuario_id"})
        self.assertEqual(datos["usuario_id"], "id-ana")
        vence = datetime.fromisoformat(datos["expiry"])
        self.assertAlmostEqual(
            (vence - datetime.now(utc.utc)).total_seconds(), timedelta(days=30).total_seconds(), delta=60,
        )
        self.assertEqual(cliente(datos["token"]).get(PERFIL).status_code, 200)

    def test_cada_login_es_una_sesion_distinta_y_las_dos_funcionan(self):
        primero, segundo = entrar().json()["token"], entrar().json()["token"]
        self.assertNotEqual(primero, segundo)
        self.assertEqual(cliente(primero).get(PERFIL).status_code, 200)
        self.assertEqual(cliente(segundo).get(PERFIL).status_code, 200)

    def test_una_cuenta_sin_perfil_recibe_usuario_id_null(self):
        User.objects.create_user("sinperfil@correo.com", password=CLAVE)
        r = entrar("sinperfil")
        self.assertEqual((r.status_code, r.json()["usuario_id"]), (200, None))

    def test_despues_de_vencer_se_vuelve_a_entrar_con_uno_nuevo(self):
        viejo = entrar().json()["token"]
        with en(dias=31):
            nuevo = entrar().json()["token"]
            self.assertEqual(cliente(viejo).get(PERFIL).status_code, 401)
            self.assertEqual(cliente(nuevo).get(PERFIL).status_code, 200)
        with en(dias=60):
            self.assertEqual(cliente(nuevo).get(PERFIL).status_code, 200)    # 29 días después

    def test_el_registro_ignora_un_token_viejo_en_el_encabezado(self):
        # Como el login: un token vencido que quedó en la app no impide crear la cuenta.
        c = cliente("token-que-ya-vencio")
        r = c.post(REGISTRO, {
            "username": "nueva@correo.com", "password": CLAVE, "birth_date": "1992-01-01",
        }, format="json")
        self.assertEqual(r.status_code, 201, r.content)

    def test_contrasena_mala_da_400(self):
        malo = entrar(password="mala")
        self.assertEqual(malo.status_code, 400)
        self.assertIn("non_field_errors", malo.json())
        self.assertFalse(AuthToken.objects.exists())

    def test_el_registro_devuelve_una_sesion_que_funciona(self):
        r = self.client.post(REGISTRO, {
            "username": "nueva@correo.com", "password": CLAVE, "birth_date": "1992-01-01",
        }, format="json")
        self.assertEqual(r.status_code, 201, r.content)
        datos = r.json()
        self.assertEqual(set(datos), {"token", "expiry", "usuario_id", "username"})
        self.assertEqual(datos["usuario_id"], Usuario.objects.get(user__username="nueva@correo.com").usuario_id)
        self.assertEqual(cliente(datos["token"]).get(PERFIL).status_code, 200)


class LimiteDeSesionesTests(APITestCase):
    """Con más de 10 sesiones se cierra la que lleva más tiempo sin usarse; la recién
    abierta, nunca (ver services/sesiones.py)."""

    def setUp(self):
        self.user = crear()

    def sesiones_abiertas(self):
        return AuthToken.objects.filter(user=self.user).count()

    def test_sin_usar_ninguna_se_cierra_la_que_se_abrio_primero(self):
        claves = [token_de(self.user) for _ in range(sesiones.MAXIMO_DE_SESIONES + 1)]
        self.assertEqual(self.sesiones_abiertas(), sesiones.MAXIMO_DE_SESIONES)
        self.assertEqual(cliente(claves[0]).get(PERFIL).status_code, 401)
        self.assertEqual(cliente(claves[1]).get(PERFIL).status_code, 200)
        self.assertEqual(cliente(claves[-1]).get(PERFIL).status_code, 200)

    def test_el_telefono_que_se_usa_a_diario_no_se_cierra(self):
        principal = cliente(token_de(self.user))             # la primera sesión: el de todos los días
        for dia in range(1, sesiones.MAXIMO_DE_SESIONES):
            with en(dias=dia):
                token_de(self.user)                          # otra sesión que nunca se usa
                principal.get(PERFIL)
        with en(dias=sesiones.MAXIMO_DE_SESIONES):
            token_de(self.user)                              # la sesión 11
            self.assertEqual(principal.get(PERFIL).status_code, 200)
        self.assertEqual(self.sesiones_abiertas(), sesiones.MAXIMO_DE_SESIONES)

    def test_la_que_llego_al_tope_de_90_dias_cuenta_como_usada_hace_poco(self):
        # Usada a diario, pasado el día 60 su vencimiento queda fijo en el día 90 y deja
        # de correrse: por el vencimiento parecería la menos usada, y no lo es.
        principal = cliente(token_de(self.user))
        for dia in range(1, 86):
            with en(dias=dia):
                principal.get(PERFIL)
                if dia >= 76:
                    token_de(self.user)                      # 10 sesiones nuevas que nunca se usan
        with en(dias=85, horas=1):
            self.assertEqual(principal.get(PERFIL).status_code, 200)
        self.assertEqual(self.sesiones_abiertas(), sesiones.MAXIMO_DE_SESIONES)

    def test_la_sesion_recien_abierta_nunca_se_cierra(self):
        # Diez que no vencen (creadas a mano en el admin) también cuentan como usadas hace poco.
        for _ in range(sesiones.MAXIMO_DE_SESIONES):
            AuthToken.objects.create(self.user, expiry=None)
        self.assertEqual(cliente(token_de(self.user)).get(PERFIL).status_code, 200)
        self.assertEqual(self.sesiones_abiertas(), sesiones.MAXIMO_DE_SESIONES)

    def test_el_limite_no_toca_otras_cuentas(self):
        beto = cliente(token_de(crear("beto")))
        for _ in range(sesiones.MAXIMO_DE_SESIONES + 1):
            token_de(self.user)
        self.assertEqual(beto.get(PERFIL).status_code, 200)


class CerrarSesionTests(APITestCase):
    def setUp(self):
        self.user = crear()
        self.este = cliente(token_de(self.user))
        self.otro_telefono = cliente(token_de(self.user))

    def test_cierra_solo_este_telefono(self):
        self.assertEqual(self.este.post(LOGOUT).status_code, 204)
        self.assertEqual(self.este.get(PERFIL).status_code, 401)
        self.assertEqual(self.otro_telefono.get(PERFIL).status_code, 200)

    def test_cerrar_todas_cierra_todos_los_telefonos(self):
        self.assertEqual(self.este.post(LOGOUT_TODOS).status_code, 204)
        self.assertEqual(self.este.get(PERFIL).status_code, 401)
        self.assertEqual(self.otro_telefono.get(PERFIL).status_code, 401)
        self.assertFalse(AuthToken.objects.filter(user=self.user).exists())

    def test_responden_204_sin_cuerpo(self):
        for url in (LOGOUT, LOGOUT_TODOS):
            with self.subTest(url=url):
                r = cliente(token_de(self.user)).post(url)
                self.assertEqual((r.status_code, r.content), (204, b""))

    def test_sin_token_o_con_uno_vencido_da_401(self):
        for url in (LOGOUT, LOGOUT_TODOS):
            with self.subTest(url=url):
                self.assertEqual(APIClient().post(url).status_code, 401)
        with en(dias=31):
            self.assertEqual(self.este.post(LOGOUT).status_code, 401)

    def test_no_toca_las_sesiones_de_otras_cuentas(self):
        beto = cliente(token_de(crear("beto")))
        self.este.post(LOGOUT_TODOS)
        self.assertEqual(beto.get(PERFIL).status_code, 200)

    def test_una_cuenta_sin_perfil_tambien_puede_cerrar_sesion(self):
        sin_perfil = User.objects.create_user("sinperfil", password=CLAVE)
        self.assertEqual(cliente(token_de(sin_perfil)).post(LOGOUT).status_code, 204)

    def test_solo_aceptan_post(self):
        for url in (LOGOUT, LOGOUT_TODOS):
            with self.subTest(url=url):
                self.assertEqual(self.este.get(url).status_code, 405)


class DiasDeVidaDeEntornoTests(TestCase):
    def leer(self, valor):
        from config import settings as ajustes
        with mock.patch.dict("os.environ", {"DIAS_DE_VIDA_DEL_TOKEN": valor}):
            return ajustes._dias_de_vida_del_token()

    def test_sin_variable_son_30_dias(self):
        from config import settings as ajustes
        with mock.patch.dict("os.environ", {}, clear=False):
            import os
            os.environ.pop("DIAS_DE_VIDA_DEL_TOKEN", None)
            self.assertEqual(ajustes._dias_de_vida_del_token(), 30)

    def test_lee_un_numero_de_dias(self):
        self.assertEqual(self.leer(" 45 "), 45)

    def test_un_valor_que_no_sirve_detiene_el_arranque_con_un_mensaje_claro(self):
        from django.core.exceptions import ImproperlyConfigured
        for malo in ("treinta", "", "0", "-5", "2.5"):
            with self.subTest(malo=malo), self.assertRaises(ImproperlyConfigured) as contexto:
                self.leer(malo)
            self.assertIn("DIAS_DE_VIDA_DEL_TOKEN", str(contexto.exception))

    def test_la_configuracion_de_knox_usa_los_dias(self):
        from django.conf import settings
        self.assertEqual(settings.REST_KNOX["TOKEN_TTL"], timedelta(days=settings.DIAS_DE_VIDA_DEL_TOKEN))
        self.assertEqual(settings.REST_KNOX["AUTO_REFRESH_MAX_TTL"], timedelta(days=90))
        self.assertTrue(settings.REST_KNOX["AUTO_REFRESH"])
        self.assertEqual(settings.REST_KNOX["MIN_REFRESH_INTERVAL"], 3600)       # una hora
        self.assertNotIn("TOKEN_LIMIT_PER_USER", settings.REST_KNOX)


class MigracionATokensDeKnoxTests(TransactionTestCase):
    """La migración 0006 pasa los tokens de DRF a Knox sin sacar a nadie de su sesión."""

    antes = [("users", "0005_uso_de_token"), ("knox", "0009_extend_authtoken_field")]
    despues = [("users", "0006_tokens_a_knox")]

    def setUp(self):
        self.executor = MigrationExecutor(connection)
        self.executor.migrate(self.antes)
        self.executor.loader.build_graph()
        viejas = self.executor.loader.project_state(self.antes).apps
        self.Token = viejas.get_model("authtoken", "Token")
        self.UsoDeToken = viejas.get_model("users", "UsoDeToken")
        self.User = viejas.get_model("auth", "User")

    def tearDown(self):
        executor = MigrationExecutor(connection)
        executor.migrate(executor.loader.graph.leaf_nodes())

    def token_viejo(self, nombre, ultimo_uso=None, creado=None):
        user = self.User.objects.create(username=nombre)
        # El modelo histórico no genera la clave como el de DRF: se pone a mano.
        token = self.Token.objects.create(user=user, key=secrets.token_hex(20))
        if creado is not None:
            self.Token.objects.filter(pk=token.pk).update(created=creado)
        if ultimo_uso is not None:
            self.UsoDeToken.objects.create(token=token, ultimo_uso=ultimo_uso)
        return token.key

    def migrar(self):
        executor = MigrationExecutor(connection)
        executor.migrate(self.despues)

    def test_un_token_vigente_sigue_funcionando_con_la_misma_clave(self):
        ahora = datetime.now(utc.utc)
        clave = self.token_viejo("ana", ultimo_uso=ahora - timedelta(days=10))
        self.migrar()

        token = AuthToken.objects.get()
        self.assertAlmostEqual(
            (token.expiry - ahora).total_seconds(), timedelta(days=20).total_seconds(), delta=60,
        )
        self.assertEqual(cliente(clave).post(LOGOUT).status_code, 204)

    def test_los_tokens_de_drf_se_borran(self):
        self.token_viejo("ana", ultimo_uso=datetime.now(utc.utc))
        self.migrar()
        from rest_framework.authtoken.models import Token
        self.assertFalse(Token.objects.exists())

    def test_uno_ya_vencido_no_se_copia(self):
        self.token_viejo("ana", ultimo_uso=datetime.now(utc.utc) - timedelta(days=31))
        self.migrar()
        self.assertFalse(AuthToken.objects.exists())

    def test_sin_registro_de_uso_cuenta_desde_que_se_creo(self):
        ahora = datetime.now(utc.utc)
        self.token_viejo("ana", creado=ahora - timedelta(days=40))
        self.token_viejo("beto", creado=ahora - timedelta(days=5))
        self.migrar()
        self.assertEqual(list(AuthToken.objects.values_list("user__username", flat=True)), ["beto"])
