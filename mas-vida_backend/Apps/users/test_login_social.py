"""POST /api/v1/login/google y /login/apple (paquete 9, 4 oct 2026)."""
import hashlib
import time
from datetime import date, timedelta
from unittest import mock

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from Apps.users.models import IdentidadExterna, Usuario
from Apps.users.test_identidad_externa import (
    APPLE_APP,
    CLAVE_DE_OTRO,
    CLAVE_DEL_PROVEEDOR,
    GOOGLE_APP,
    emitir,
)
from services import identidad_externa as ie
from services import login_social

User = get_user_model()

GOOGLE_URL = "/api/v1/login/google"
APPLE_URL = "/api/v1/login/apple"
NACIMIENTO = "1990-05-17"


class _ConProveedor:
    def setUp(self):
        super().setUp()
        self.enterContext(self.settings(GOOGLE_CLIENT_IDS=[GOOGLE_APP], APPLE_CLIENT_IDS=[APPLE_APP]))
        # Lo único con red es pedir la clave pública; aquí es la del proveedor de mentira.
        parche = mock.patch.object(ie, "_clave_de", return_value=CLAVE_DEL_PROVEEDOR.public_key())
        parche.start()
        self.addCleanup(parche.stop)

    def entrar(self, url=GOOGLE_URL, proveedor=ie.GOOGLE, birth_date=NACIMIENTO, token=None, **cuerpo):
        datos = {"credencial": token or emitir(proveedor)}
        if birth_date:
            datos["birth_date"] = birth_date
        datos.update(cuerpo)
        return self.client.post(url, datos, format="json")


class PrimeraVezTests(_ConProveedor, APITestCase):
    def test_sin_fecha_de_nacimiento_no_se_crea_nada_y_se_pide(self):
        r = self.entrar(birth_date=None)
        self.assertEqual(r.status_code, 422)
        self.assertEqual(r.json()["error"], "falta_fecha_nacimiento")
        self.assertFalse(User.objects.exists())
        self.assertFalse(IdentidadExterna.objects.exists())

    def test_con_fecha_de_nacimiento_crea_la_cuenta_y_devuelve_el_token(self):
        r = self.entrar()
        self.assertEqual(r.status_code, 201, r.content)
        datos = r.json()
        self.assertTrue(datos["nuevo"])
        self.assertTrue(datos["token"])
        user = User.objects.get(username=datos["username"])
        self.assertTrue(user.username.startswith("google-"))
        self.assertFalse(user.has_usable_password())          # solo entra con su proveedor
        usuario = Usuario.objects.get(user=user)
        self.assertEqual(usuario.birth_date, date(1990, 5, 17))
        self.assertEqual(usuario.usuario_id, datos["usuario_id"])
        identidad = IdentidadExterna.objects.get(user=user)
        self.assertEqual((identidad.proveedor, identidad.sub), ("google", "109876543210"))

    def test_el_token_sirve_en_el_resto_de_la_api(self):
        token = self.entrar().json()["token"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
        self.assertEqual(self.client.get("/api/v1/polizas/estado").status_code, 200)

    def test_apple_crea_la_cuenta_igual(self):
        r = self.entrar(APPLE_URL, ie.APPLE)
        self.assertEqual(r.status_code, 201, r.content)
        self.assertTrue(r.json()["username"].startswith("apple-"))

    def test_una_fecha_de_nacimiento_futura_se_rechaza_y_no_crea_nada(self):
        futura = (timezone.localdate() + timedelta(days=1)).isoformat()
        r = self.entrar(birth_date=futura)
        self.assertEqual(r.status_code, 400)
        self.assertIn("birth_date", r.json())
        self.assertFalse(User.objects.exists())

    def test_sin_credencial_es_400(self):
        r = self.client.post(GOOGLE_URL, {"birth_date": NACIMIENTO}, format="json")
        self.assertEqual(r.status_code, 400)
        self.assertIn("credencial", r.json())

    def test_solo_acepta_post(self):
        self.assertEqual(self.client.get(GOOGLE_URL).status_code, 405)


class CuentaExistenteTests(_ConProveedor, APITestCase):
    def test_la_segunda_vez_devuelve_la_misma_cuenta_sin_pedir_fecha(self):
        primero = self.entrar().json()
        r = self.entrar(birth_date=None)
        self.assertEqual(r.status_code, 200, r.content)
        segundo = r.json()
        self.assertFalse(segundo["nuevo"])
        self.assertEqual(
            (segundo["token"], segundo["usuario_id"], segundo["username"]),
            (primero["token"], primero["usuario_id"], primero["username"]),
        )
        self.assertEqual(User.objects.count(), 1)

    def test_una_fecha_que_llega_despues_nunca_cambia_la_guardada(self):
        self.entrar()
        self.entrar(birth_date="1960-01-01")
        self.assertEqual(Usuario.objects.get().birth_date, date(1990, 5, 17))

    def test_otra_persona_del_mismo_proveedor_es_otra_cuenta(self):
        self.entrar()
        r = self.entrar(token=emitir(ie.GOOGLE, sub="otro-sub"))
        self.assertTrue(r.json()["nuevo"])
        self.assertEqual(User.objects.count(), 2)

    def test_el_mismo_sub_en_otro_proveedor_es_otra_cuenta(self):
        self.entrar(GOOGLE_URL, ie.GOOGLE)
        r = self.entrar(APPLE_URL, ie.APPLE, token=emitir(ie.APPLE, sub="109876543210"))
        self.assertTrue(r.json()["nuevo"])
        self.assertEqual(User.objects.count(), 2)

    def test_no_se_une_a_una_cuenta_con_usuario_y_contrasena(self):
        User.objects.create_user("ana", password="clave-segura-1")
        self.entrar()
        self.assertEqual(User.objects.count(), 2)
        self.assertFalse(IdentidadExterna.objects.filter(user__username="ana").exists())

    def test_una_cuenta_social_no_entra_con_contrasena(self):
        username = self.entrar().json()["username"]
        for clave in ("", "cualquiera", "clave-segura-1"):
            with self.subTest(clave=clave):
                r = self.client.post(
                    "/api/v1/login", {"username": username, "password": clave}, format="json",
                )
                self.assertEqual(r.status_code, 400)

    def test_una_cuenta_desactivada_no_entra(self):
        self.entrar()
        User.objects.update(is_active=False)
        r = self.entrar(birth_date=None)
        self.assertEqual(r.status_code, 403)
        self.assertEqual(r.json()["error"], "cuenta_inactiva")

    def test_un_token_viejo_en_el_encabezado_no_impide_entrar(self):
        self.client.credentials(HTTP_AUTHORIZATION="Token basura")
        self.assertEqual(self.entrar().status_code, 201)


class CorreoExistenteTests(_ConProveedor, APITestCase):
    """+Vida usa el correo como `username` en las cuentas con contraseña."""

    def verificado(self, correo="ana@gmail.com", proveedor=ie.GOOGLE, **cambios):
        return emitir(proveedor, email=correo, email_verified=True, **cambios)

    def assertConflicto(self, r, metodo):
        self.assertEqual(r.status_code, 409, r.content)
        self.assertEqual(r.json()["error"], "correo_ya_registrado")
        self.assertEqual(r.json()["metodo"], metodo)

    def test_si_el_correo_ya_tiene_cuenta_con_contrasena_avisa_y_no_crea(self):
        User.objects.create_user("ana@gmail.com", password="clave-segura-1")
        r = self.entrar(token=self.verificado())
        self.assertConflicto(r, "contrasena")
        self.assertEqual(User.objects.count(), 1)
        self.assertFalse(IdentidadExterna.objects.exists())

    def test_la_comparacion_no_distingue_mayusculas(self):
        User.objects.create_user("Ana@Gmail.COM", password="clave-segura-1")
        self.assertConflicto(self.entrar(token=self.verificado("ana@gmail.com")), "contrasena")

    def test_el_aviso_va_antes_de_pedir_la_fecha_de_nacimiento(self):
        User.objects.create_user("ana@gmail.com", password="clave-segura-1")
        self.assertConflicto(self.entrar(token=self.verificado(), birth_date=None), "contrasena")

    def test_tambien_cuenta_el_correo_guardado_en_una_cuenta_con_otro_usuario(self):
        User.objects.create_user("ana", email="ANA@gmail.com", password="clave-segura-1")
        self.assertConflicto(self.entrar(token=self.verificado()), "contrasena")

    def test_si_ya_entro_con_google_y_prueba_apple_dice_con_cual_entro(self):
        self.entrar(token=self.verificado())
        r = self.entrar(APPLE_URL, ie.APPLE, token=self.verificado(proveedor=ie.APPLE))
        self.assertConflicto(r, "google")
        self.assertEqual(User.objects.count(), 1)

    def test_si_la_cuenta_ya_es_suya_entra_aunque_otra_tenga_ese_correo(self):
        primero = self.entrar(token=self.verificado()).json()
        User.objects.create_user("ana@gmail.com", password="clave-segura-1")   # llegó después
        r = self.entrar(token=self.verificado(), birth_date=None)
        self.assertEqual(r.status_code, 200, r.content)
        self.assertEqual(r.json()["usuario_id"], primero["usuario_id"])

    def test_un_correo_nuevo_se_guarda_en_minusculas_en_la_cuenta(self):
        r = self.entrar(token=self.verificado("Ana.Nueva@Gmail.com"))
        self.assertEqual(r.status_code, 201, r.content)
        self.assertEqual(User.objects.get(username=r.json()["username"]).email, "ana.nueva@gmail.com")

    def test_un_correo_sin_verificar_no_choca_ni_se_guarda(self):
        User.objects.create_user("ana@gmail.com", password="clave-segura-1")
        token = emitir(email="ana@gmail.com", email_verified=False)
        r = self.entrar(token=token)
        self.assertEqual(r.status_code, 201, r.content)
        self.assertEqual(User.objects.get(username=r.json()["username"]).email, "")

    def test_sin_correo_en_el_token_crea_la_cuenta_sin_correo(self):
        r = self.entrar()
        self.assertEqual(r.status_code, 201, r.content)
        self.assertEqual(User.objects.get(username=r.json()["username"]).email, "")

    def test_un_correo_de_reenvio_de_apple_no_choca_con_nadie(self):
        User.objects.create_user("ana@gmail.com", password="clave-segura-1")
        token = self.verificado("abc123@privaterelay.appleid.com", ie.APPLE)
        r = self.entrar(APPLE_URL, ie.APPLE, token=token)
        self.assertEqual(r.status_code, 201, r.content)


class CredencialInvalidaTests(_ConProveedor, APITestCase):
    def assertRechazada(self, r):
        self.assertEqual(r.status_code, 401, r.content)
        self.assertEqual(r.json()["error"], "credencial_invalida")
        self.assertFalse(User.objects.exists())
        self.assertFalse(IdentidadExterna.objects.exists())

    def test_firmada_por_otro(self):
        self.assertRechazada(self.entrar(token=emitir(firma=CLAVE_DE_OTRO)))

    def test_vencida(self):
        self.assertRechazada(self.entrar(token=emitir(exp=int(time.time()) - 60)))

    def test_para_otra_app(self):
        self.assertRechazada(self.entrar(token=emitir(aud="otra-app")))

    def test_un_texto_cualquiera(self):
        self.assertRechazada(self.entrar(token="esto-no-es-un-token"))

    def test_un_token_de_apple_en_la_ruta_de_google(self):
        self.assertRechazada(self.entrar(GOOGLE_URL, token=emitir(ie.APPLE)))

    def test_el_error_no_repite_la_credencial(self):
        token = emitir(firma=CLAVE_DE_OTRO)
        self.assertNotIn(token, self.entrar(token=token).content.decode())


class NonceTests(_ConProveedor, APITestCase):
    def test_con_el_nonce_correcto_entra(self):
        token = emitir(ie.APPLE, nonce=hashlib.sha256(b"abc123").hexdigest())
        r = self.entrar(APPLE_URL, ie.APPLE, token=token, nonce="abc123")
        self.assertEqual(r.status_code, 201, r.content)

    def test_con_otro_nonce_se_rechaza(self):
        token = emitir(ie.APPLE, nonce=hashlib.sha256(b"abc123").hexdigest())
        r = self.entrar(APPLE_URL, ie.APPLE, token=token, nonce="otro")
        self.assertEqual(r.status_code, 401)
        self.assertFalse(User.objects.exists())

    def test_si_el_token_trae_nonce_la_app_tiene_que_mandarlo(self):
        token = emitir(ie.APPLE, nonce="abc123")
        self.assertEqual(self.entrar(APPLE_URL, ie.APPLE, token=token).status_code, 401)


class ProveedorNoDisponibleTests(TestCase):
    @override_settings(GOOGLE_CLIENT_IDS=[], APPLE_CLIENT_IDS=[])
    def test_sin_configurar_responde_503_y_no_crea_nada(self):
        for url, proveedor in ((GOOGLE_URL, ie.GOOGLE), (APPLE_URL, ie.APPLE)):
            with self.subTest(url=url):
                r = self.client.post(
                    url, {"credencial": emitir(proveedor), "birth_date": NACIMIENTO},
                    content_type="application/json",
                )
                self.assertEqual(r.status_code, 503)
                self.assertEqual(r.json()["error"], "proveedor_no_configurado")
        self.assertFalse(User.objects.exists())

    @override_settings(GOOGLE_CLIENT_IDS=[GOOGLE_APP])
    def test_si_no_hay_red_para_pedir_las_claves_responde_503(self):
        with mock.patch.object(ie, "_clave_de", side_effect=ie.ProveedorNoDisponible()):
            r = self.client.post(
                GOOGLE_URL, {"credencial": emitir(), "birth_date": NACIMIENTO},
                content_type="application/json",
            )
        self.assertEqual(r.status_code, 503)
        self.assertEqual(r.json()["error"], "proveedor_no_disponible")
        self.assertFalse(User.objects.exists())


class CarreraTests(TestCase):
    def test_si_otra_peticion_creo_la_misma_identidad_gana_la_otra(self):
        user = User.objects.create_user("google-previo")
        Usuario.objects.create(user=user, usuario_id="previo", birth_date=date(1990, 1, 1))
        existente = IdentidadExterna.objects.create(user=user, proveedor="google", sub="s1")
        identidad = ie.Identidad("google", "s1")

        # La primera búsqueda no la ve (la otra petición aún no terminaba); al crear choca.
        with mock.patch.object(login_social, "_buscar", side_effect=[None, existente]):
            resultado, nuevo = login_social.entrar(identidad, date(1980, 1, 1))

        self.assertEqual((resultado, nuevo), (user, False))
        self.assertEqual(User.objects.count(), 1)
