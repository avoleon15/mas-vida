"""El token vence a los 30 días sin uso y se puede cerrar sesión (etapa 10, 4 oct 2026)."""
from datetime import date, datetime, timedelta, timezone as utc
from importlib import import_module
from unittest import mock

from django.apps import apps
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient, APITestCase

from Apps.users.models import UsoDeToken, Usuario
from services import sesiones

User = get_user_model()

PERFIL = "/api/v1/perfil"
LOGIN = "/api/v1/login"
LOGOUT = "/api/v1/logout"
REGISTRO = "/api/v1/registro"

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
    user = User.objects.create_user(f"{nombre}@correo.com", password="Clave-segura-2026", **extra)
    Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=date(1990, 5, 17))
    return user


def cliente(token):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
    return c


class VidaDelTokenTests(APITestCase):
    def setUp(self):
        self.user = crear()
        self.token = Token.objects.get(user=self.user)
        self.c = cliente(self.token)

    def uso(self):
        return UsoDeToken.objects.get(token=self.token).ultimo_uso

    def test_un_token_recien_creado_funciona(self):
        self.assertEqual(self.c.get(PERFIL).status_code, 200)

    def test_sin_uso_funciona_hasta_los_30_dias_y_vence_despues(self):
        self.c.get(PERFIL)
        with en(dias=29, horas=23):
            self.assertEqual(self.c.get(PERFIL).status_code, 200)

    def test_pasados_30_dias_sin_uso_da_401_con_su_mensaje(self):
        self.c.get(PERFIL)
        with en(dias=31):
            r = self.c.get(PERFIL)
        self.assertEqual(r.status_code, 401)
        self.assertIn("venció", r.json()["detail"])
        self.assertEqual(r["WWW-Authenticate"], "Token")

    def test_cada_uso_renueva_el_plazo(self):
        self.c.get(PERFIL)
        with en(dias=29):
            self.assertEqual(self.c.get(PERFIL).status_code, 200)       # renueva
        with en(dias=58):
            self.assertEqual(self.c.get(PERFIL).status_code, 200)       # 29 días después: sigue
            self.assertEqual(self.c.get(PERFIL).status_code, 200)
        with en(dias=90):
            self.assertEqual(self.c.get(PERFIL).status_code, 401)       # 32 días sin usar

    def test_el_ultimo_uso_se_escribe_a_lo_mas_una_vez_por_hora(self):
        self.c.get(PERFIL)
        primero = self.uso()
        with en(minutos=30):
            self.c.get(PERFIL)
        self.assertEqual(self.uso(), primero)
        with en(horas=2):
            self.c.get(PERFIL)
        self.assertGreater(self.uso(), primero + timedelta(hours=1))

    def test_un_token_sin_registro_de_uso_cuenta_desde_que_se_creo(self):
        UsoDeToken.objects.filter(token=self.token).delete()
        Token.objects.filter(pk=self.token.pk).update(created=datetime.now(utc.utc) - timedelta(days=40))
        self.assertEqual(self.c.get(PERFIL).status_code, 401)

    def test_un_token_reciente_sin_registro_funciona_y_queda_anotado(self):
        UsoDeToken.objects.filter(token=self.token).delete()
        self.assertEqual(self.c.get(PERFIL).status_code, 200)
        self.assertTrue(UsoDeToken.objects.filter(token=self.token).exists())

    def test_un_token_inexistente_sigue_dando_401(self):
        c = APIClient()
        c.credentials(HTTP_AUTHORIZATION="Token no-existe")
        self.assertEqual(c.get(PERFIL).status_code, 401)

    def test_una_cuenta_desactivada_da_401(self):
        User.objects.filter(pk=self.user.pk).update(is_active=False)
        self.assertEqual(self.c.get(PERFIL).status_code, 401)

    @override_settings(DIAS_DE_VIDA_DEL_TOKEN=10)
    def test_los_dias_se_pueden_cambiar_en_la_configuracion(self):
        self.c.get(PERFIL)
        with en(dias=9):
            self.assertEqual(self.c.get(PERFIL).status_code, 200)
        with en(dias=30):
            self.assertEqual(self.c.get(PERFIL).status_code, 401)

    def test_todos_los_endpoints_rechazan_un_token_vencido(self):
        self.c.get(PERFIL)
        with en(dias=31):
            for url in ENDPOINTS_GET:
                with self.subTest(url=url):
                    self.assertEqual(self.c.get(url).status_code, 401)
            for url in ("/api/v1/sync", "/api/v1/polizas/vincular", "/api/v1/ligas", "/api/v1/ligas/unirse",
                        "/api/v1/premios/1/canjear", LOGOUT):
                with self.subTest(url=url):
                    self.assertEqual(self.c.post(url, {}, format="json").status_code, 401)

    def test_los_endpoints_aceptan_el_token_vigente(self):
        for url in ENDPOINTS_GET:
            with self.subTest(url=url):
                self.assertNotEqual(self.c.get(url).status_code, 401)


class IniciarSesionTests(APITestCase):
    def setUp(self):
        self.user = crear()
        self.token = Token.objects.get(user=self.user)

    def entrar(self, **extra):
        return self.client.post(
            LOGIN, {"username": "ana@correo.com", "password": "Clave-segura-2026"}, format="json", **extra,
        )

    def test_con_un_token_vigente_devuelve_el_mismo_y_lo_renueva(self):
        UsoDeToken.objects.update_or_create(
            token=self.token, defaults={"ultimo_uso": datetime.now(utc.utc) - timedelta(days=20)},
        )
        r = self.entrar()
        self.assertEqual((r.status_code, r.json()["token"]), (200, self.token.key))
        self.assertGreater(UsoDeToken.objects.get(token=self.token).ultimo_uso, datetime.now(utc.utc) - timedelta(minutes=1))

    def test_un_token_vencido_nunca_se_revive_se_entrega_uno_nuevo(self):
        with en(dias=31):
            r = self.entrar()
            nuevo = r.json()["token"]
            self.assertEqual(r.status_code, 200)
            self.assertNotEqual(nuevo, self.token.key)
            # La llave vieja no sirve ni siquiera ahora que la cuenta volvió a entrar...
            self.assertEqual(cliente(self.token).get(PERFIL).status_code, 401)
            # ...y la nueva sí.
            self.assertEqual(APIClient(HTTP_AUTHORIZATION=f"Token {nuevo}").get(PERFIL).status_code, 200)
        self.assertEqual(Token.objects.filter(user=self.user).count(), 1)

    def test_el_token_nuevo_arranca_con_su_propio_plazo(self):
        with en(dias=31):
            nuevo = Token.objects.get(key=self.entrar().json()["token"])
        with en(dias=60):
            self.assertEqual(cliente(nuevo).get(PERFIL).status_code, 200)    # 29 días después

    def test_el_registro_anota_el_uso_y_devuelve_un_token_que_funciona(self):
        r = self.client.post(REGISTRO, {
            "username": "nueva@correo.com", "password": "Clave-segura-2026", "birth_date": "1992-01-01",
        }, format="json")
        self.assertEqual(r.status_code, 201, r.content)
        token = Token.objects.get(key=r.json()["token"])
        self.assertTrue(UsoDeToken.objects.filter(token=token).exists())
        self.assertEqual(cliente(token).get(PERFIL).status_code, 200)

    def test_el_login_sigue_respondiendo_con_la_forma_de_siempre(self):
        r = self.entrar()
        self.assertEqual(set(r.json()), {"token"})
        malo = self.client.post(LOGIN, {"username": "ana@correo.com", "password": "mala"}, format="json")
        self.assertEqual(malo.status_code, 400)
        self.assertIn("non_field_errors", malo.json())


class CerrarSesionTests(APITestCase):
    def setUp(self):
        self.user = crear()
        self.token = Token.objects.get(user=self.user)
        self.c = cliente(self.token)

    def test_cerrar_sesion_borra_el_token_y_ya_no_sirve(self):
        self.assertEqual(self.c.post(LOGOUT).status_code, 204)
        self.assertFalse(Token.objects.filter(user=self.user).exists())
        self.assertEqual(self.c.get(PERFIL).status_code, 401)

    def test_responde_204_sin_cuerpo(self):
        r = self.c.post(LOGOUT)
        self.assertEqual((r.status_code, r.content), (204, b""))

    def test_sin_token_o_con_uno_vencido_da_401(self):
        self.assertEqual(APIClient().post(LOGOUT).status_code, 401)
        with en(dias=31):
            self.assertEqual(self.c.post(LOGOUT).status_code, 401)

    def test_cierra_la_sesion_en_todos_los_dispositivos_de_la_cuenta(self):
        otro_telefono = cliente(self.token)       # el mismo token en otro aparato
        self.c.post(LOGOUT)
        self.assertEqual(otro_telefono.get(PERFIL).status_code, 401)

    def test_despues_de_cerrar_sesion_se_puede_volver_a_entrar_con_un_token_nuevo(self):
        viejo = self.token.key
        self.c.post(LOGOUT)
        r = self.client.post(LOGIN, {"username": "ana@correo.com", "password": "Clave-segura-2026"}, format="json")
        self.assertEqual(r.status_code, 200)
        self.assertNotEqual(r.json()["token"], viejo)
        self.assertEqual(APIClient(HTTP_AUTHORIZATION=f"Token {r.json()['token']}").get(PERFIL).status_code, 200)

    def test_no_toca_las_sesiones_de_otras_cuentas(self):
        beto = crear("beto")
        token_beto = Token.objects.get(user=beto)
        self.c.post(LOGOUT)
        self.assertEqual(cliente(token_beto).get(PERFIL).status_code, 200)

    def test_una_cuenta_sin_perfil_tambien_puede_cerrar_sesion(self):
        sin_perfil = User.objects.create_user("sinperfil", password="Clave-segura-2026")
        self.assertEqual(cliente(Token.objects.get(user=sin_perfil)).post(LOGOUT).status_code, 204)

    def test_solo_acepta_post(self):
        self.assertEqual(self.c.get(LOGOUT).status_code, 405)


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


class MigracionDeTokensExistentesTests(TestCase):
    def test_los_tokens_que_ya_existian_arrancan_con_30_dias_desde_migrar(self):
        migracion = import_module("Apps.users.migrations.0005_uso_de_token")
        user = crear()
        viejo = Token.objects.get(user=user)
        Token.objects.filter(pk=viejo.pk).update(created=datetime.now(utc.utc) - timedelta(days=90))
        UsoDeToken.objects.all().delete()          # como estaba la base antes de la migración

        migracion.crear_usos_de_los_tokens_existentes(apps, None)

        uso = UsoDeToken.objects.get(token=viejo)
        self.assertGreater(uso.ultimo_uso, datetime.now(utc.utc) - timedelta(minutes=1))
        self.assertEqual(cliente(viejo).get(PERFIL).status_code, 200)    # no se vence de golpe

    def test_correrla_dos_veces_no_duplica(self):
        migracion = import_module("Apps.users.migrations.0005_uso_de_token")
        crear()
        migracion.crear_usos_de_los_tokens_existentes(apps, None)
        migracion.crear_usos_de_los_tokens_existentes(apps, None)
        self.assertEqual(UsoDeToken.objects.count(), 1)
