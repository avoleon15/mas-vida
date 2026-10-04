"""Verificación de credenciales de Google y Apple (paquete 9, 4 oct 2026)."""
import hashlib
import time
from unittest import mock

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from django.test import SimpleTestCase, override_settings

from services import identidad_externa as ie

# Las claves se generan una vez: hacerlo en cada prueba tardaría.
CLAVE_DEL_PROVEEDOR = rsa.generate_private_key(public_exponent=65537, key_size=2048)
CLAVE_DE_OTRO = rsa.generate_private_key(public_exponent=65537, key_size=2048)

GOOGLE_APP = "1234-ios.apps.googleusercontent.com"
APPLE_APP = "com.assures.masvida"

EMISOR = {
    ie.GOOGLE: "https://accounts.google.com",
    ie.APPLE: "https://appleid.apple.com",
}
AUDIENCIA = {ie.GOOGLE: GOOGLE_APP, ie.APPLE: APPLE_APP}


def emitir(proveedor=ie.GOOGLE, firma=CLAVE_DEL_PROVEEDOR, algoritmo="RS256", **cambios):
    """Un token como el que mandaría el proveedor; `cambios` pisa o quita claims (None quita)."""
    claims = {
        "iss": EMISOR[proveedor],
        "aud": AUDIENCIA[proveedor],
        "sub": "109876543210",
        "exp": int(time.time()) + 600,
        "iat": int(time.time()),
    }
    claims.update(cambios)
    claims = {k: v for k, v in claims.items() if v is not None}
    return jwt.encode(claims, firma, algorithm=algoritmo)


@override_settings(GOOGLE_CLIENT_IDS=[GOOGLE_APP], APPLE_CLIENT_IDS=[APPLE_APP])
class VerificarTests(SimpleTestCase):
    def setUp(self):
        # Lo único con red es pedir la clave pública; aquí es la del proveedor de mentira.
        parche = mock.patch.object(ie, "_clave_de", return_value=CLAVE_DEL_PROVEEDOR.public_key())
        parche.start()
        self.addCleanup(parche.stop)

    def assertInvalida(self, *args, **kwargs):
        with self.assertRaises(ie.CredencialInvalida):
            ie.verificar(*args, **kwargs)

    def test_google_valido_devuelve_proveedor_y_sub(self):
        self.assertEqual(
            ie.verificar(ie.GOOGLE, emitir()), ie.Identidad("google", "109876543210"),
        )

    def test_apple_valido_devuelve_proveedor_y_sub(self):
        token = emitir(ie.APPLE, sub="001234.abcd.0987")
        self.assertEqual(ie.verificar(ie.APPLE, token), ie.Identidad("apple", "001234.abcd.0987"))

    def test_google_acepta_sus_dos_formas_de_emisor(self):
        for emisor in ("https://accounts.google.com", "accounts.google.com"):
            with self.subTest(emisor=emisor):
                self.assertEqual(ie.verificar(ie.GOOGLE, emitir(iss=emisor)).sub, "109876543210")

    def test_firmado_por_otra_clave_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(firma=CLAVE_DE_OTRO))

    def test_vencido_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(exp=int(time.time()) - 60))

    def test_sin_vencimiento_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(exp=None))

    def test_emitido_para_otra_app_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(aud="otra-app.apps.googleusercontent.com"))
        self.assertInvalida(ie.APPLE, emitir(ie.APPLE, aud="com.otra.app"))

    def test_sin_audiencia_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(aud=None))

    def test_emisor_equivocado_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(iss="https://evil.example.com"))

    def test_un_token_de_apple_no_vale_como_de_google_ni_al_reves(self):
        self.assertInvalida(ie.GOOGLE, emitir(ie.APPLE, aud=GOOGLE_APP))
        self.assertInvalida(ie.APPLE, emitir(ie.GOOGLE, aud=APPLE_APP))

    def test_sin_sub_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(sub=None))
        self.assertInvalida(ie.GOOGLE, emitir(sub=""))

    def test_un_sub_que_no_es_texto_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(sub=12345))

    def test_un_token_firmado_con_hs256_no_pasa(self):
        # Ataque clásico: firmar con una clave simétrica cualquiera.
        self.assertInvalida(ie.GOOGLE, emitir(firma="secreto-" * 8, algoritmo="HS256"))

    def test_un_token_sin_firma_no_pasa(self):
        sin_firma = jwt.encode(
            {"iss": EMISOR[ie.GOOGLE], "aud": GOOGLE_APP, "sub": "1", "exp": int(time.time()) + 600},
            key=None, algorithm="none",
        )
        self.assertInvalida(ie.GOOGLE, sin_firma)

    def test_con_varias_audiencias_basta_una(self):
        with override_settings(GOOGLE_CLIENT_IDS=["otro-id", GOOGLE_APP]):
            self.assertEqual(ie.verificar(ie.GOOGLE, emitir()).sub, "109876543210")

    # --- correo ------------------------------------------------------------

    def test_el_correo_verificado_sale_en_minusculas(self):
        token = emitir(email="Ana.Perez@Gmail.com", email_verified=True)
        self.assertEqual(ie.verificar(ie.GOOGLE, token).email, "ana.perez@gmail.com")

    def test_apple_manda_email_verified_como_texto(self):
        token = emitir(ie.APPLE, email="ana@icloud.com", email_verified="true")
        self.assertEqual(ie.verificar(ie.APPLE, token).email, "ana@icloud.com")

    def test_un_correo_sin_verificar_no_se_toma(self):
        for verificado in (False, "false", None):
            with self.subTest(verificado=verificado):
                token = emitir(email="ana@gmail.com", email_verified=verificado)
                self.assertIsNone(ie.verificar(ie.GOOGLE, token).email)

    def test_sin_correo_o_con_uno_que_no_parece_correo_es_none(self):
        self.assertIsNone(ie.verificar(ie.GOOGLE, emitir()).email)
        self.assertIsNone(ie.verificar(ie.GOOGLE, emitir(email="no-es-correo", email_verified=True)).email)
        self.assertIsNone(ie.verificar(ie.GOOGLE, emitir(email=123, email_verified=True)).email)

    # --- nonce -------------------------------------------------------------

    def test_el_nonce_en_claro_coincide(self):
        token = emitir(nonce="abc123")
        self.assertEqual(ie.verificar(ie.GOOGLE, token, nonce="abc123").sub, "109876543210")

    def test_el_nonce_en_sha256_coincide(self):
        # Apple pone en el token el SHA-256 del nonce que la app le dio.
        hash_ = hashlib.sha256(b"abc123").hexdigest()
        self.assertEqual(ie.verificar(ie.APPLE, emitir(ie.APPLE, nonce=hash_), nonce="abc123").sub, "109876543210")

    def test_un_nonce_distinto_se_rechaza(self):
        self.assertInvalida(ie.GOOGLE, emitir(nonce="abc123"), nonce="otro")

    def test_si_el_token_trae_nonce_la_app_tiene_que_mandarlo(self):
        self.assertInvalida(ie.GOOGLE, emitir(nonce="abc123"))

    def test_si_la_app_manda_nonce_el_token_tiene_que_traerlo(self):
        self.assertInvalida(ie.GOOGLE, emitir(), nonce="abc123")

    def test_sin_nonce_en_ningun_lado_es_valido(self):
        self.assertEqual(ie.verificar(ie.GOOGLE, emitir()).sub, "109876543210")


class SinRedTests(SimpleTestCase):
    @override_settings(GOOGLE_CLIENT_IDS=[], APPLE_CLIENT_IDS=[])
    def test_un_proveedor_sin_identificadores_esta_apagado(self):
        for proveedor in ie.PROVEEDORES:
            with self.subTest(proveedor=proveedor), self.assertRaises(ie.ProveedorNoConfigurado):
                ie.verificar(proveedor, emitir(proveedor))

    @override_settings(GOOGLE_CLIENT_IDS=[GOOGLE_APP])
    def test_un_texto_que_no_es_un_jwt_se_rechaza_sin_pedir_claves(self):
        with self.assertRaises(ie.CredencialInvalida):
            ie.verificar(ie.GOOGLE, "esto-no-es-un-token")

    @override_settings(GOOGLE_CLIENT_IDS=[GOOGLE_APP])
    def test_si_no_se_pueden_pedir_las_claves_es_un_problema_del_proveedor(self):
        with mock.patch.object(
            ie.PyJWKClient, "get_signing_key_from_jwt",
            side_effect=jwt.PyJWKClientConnectionError("sin red"),
        ), self.assertRaises(ie.ProveedorNoDisponible):
            ie.verificar(ie.GOOGLE, emitir())

    @override_settings(GOOGLE_CLIENT_IDS=[GOOGLE_APP])
    def test_un_kid_que_el_proveedor_no_tiene_es_una_credencial_invalida(self):
        with mock.patch.object(
            ie.PyJWKClient, "get_signing_key_from_jwt",
            side_effect=jwt.PyJWKClientError("kid desconocido"),
        ), self.assertRaises(ie.CredencialInvalida):
            ie.verificar(ie.GOOGLE, emitir())
