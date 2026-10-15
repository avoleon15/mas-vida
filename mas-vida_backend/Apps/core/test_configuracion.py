"""La configuración sale de variables de entorno y el servidor no arranca mal configurado (etapa 7).

La configuración se lee una sola vez, al arrancar: cada prueba arranca Django en un
proceso aparte con las variables que quiere probar.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

from django.test import SimpleTestCase

BACKEND = Path(__file__).resolve().parents[2]
VARIABLES = (
    "DEBUG", "SECRET_KEY", "ALLOWED_HOSTS", "CSRF_TRUSTED_ORIGINS", "NUM_PROXIES_CONFIABLES",
    "SECURE_SSL_REDIRECT", "SECURE_HSTS_SECONDS", "SECURE_HSTS_INCLUDE_SUBDOMAINS", "SECURE_HSTS_PRELOAD",
    "DB_ENGINE", "DB_SSLMODE", "DB_CONN_MAX_AGE",
)
LEER = """
import json, django
from django.conf import settings
django.setup()
db = settings.DATABASES["default"]
print(json.dumps({
    "DEBUG": settings.DEBUG, "SECRET_KEY": settings.SECRET_KEY,
    "ALLOWED_HOSTS": settings.ALLOWED_HOSTS, "CSRF_TRUSTED_ORIGINS": settings.CSRF_TRUSTED_ORIGINS,
    "NUM_PROXIES_CONFIABLES": settings.NUM_PROXIES_CONFIABLES,
    "SECURE_SSL_REDIRECT": getattr(settings, "SECURE_SSL_REDIRECT", False),
    "SESSION_COOKIE_SECURE": settings.SESSION_COOKIE_SECURE, "CSRF_COOKIE_SECURE": settings.CSRF_COOKIE_SECURE,
    "SECURE_HSTS_SECONDS": settings.SECURE_HSTS_SECONDS,
    "SECURE_PROXY_SSL_HEADER": settings.SECURE_PROXY_SSL_HEADER,
    "DB_OPTIONS": db.get("OPTIONS", {}), "CONN_MAX_AGE": db.get("CONN_MAX_AGE"),
}))
"""
SERVIDOR = {"SECRET_KEY": "una-clave-larga-de-prueba-" + "x" * 40, "ALLOWED_HOSTS": "api.ejemplo.com"}


def arrancar(**variables):
    """Arranca Django con esas variables (y ninguna de las demás). Devuelve (código, salida)."""
    entorno = {k: v for k, v in os.environ.items() if k not in VARIABLES}
    entorno.update(variables, DJANGO_SETTINGS_MODULE="config.settings")
    proceso = subprocess.run(
        [sys.executable, "-c", LEER], cwd=BACKEND, env=entorno, capture_output=True, text=True, timeout=120,
    )
    return proceso.returncode, proceso.stdout + proceso.stderr


def configuracion(**variables):
    codigo, salida = arrancar(**variables)
    assert codigo == 0, salida
    return json.loads(salida.strip().splitlines()[-1])


class ServidorTests(SimpleTestCase):
    def test_sin_debug_ni_clave_no_arranca_y_dice_como_generarla(self):
        codigo, salida = arrancar()
        self.assertNotEqual(codigo, 0)
        self.assertIn("Falta SECRET_KEY", salida)
        self.assertIn("get_random_secret_key", salida)

    def test_sin_hosts_no_arranca(self):
        codigo, salida = arrancar(SECRET_KEY=SERVIDOR["SECRET_KEY"])
        self.assertNotEqual(codigo, 0)
        self.assertIn("Falta ALLOWED_HOSTS", salida)

    def test_debug_viene_apagado_por_defecto(self):
        self.assertFalse(configuracion(**SERVIDOR)["DEBUG"])

    def test_con_todo_configurado_exige_https(self):
        c = configuracion(**SERVIDOR)
        self.assertTrue(c["SECURE_SSL_REDIRECT"])
        self.assertTrue(c["SESSION_COOKIE_SECURE"])
        self.assertTrue(c["CSRF_COOKIE_SECURE"])
        self.assertEqual(c["SECURE_HSTS_SECONDS"], 30 * 24 * 3600)
        self.assertEqual(c["SECURE_PROXY_SSL_HEADER"], ["HTTP_X_FORWARDED_PROTO", "https"])

    def test_listas_separadas_por_coma(self):
        c = configuracion(**{
            **SERVIDOR, "ALLOWED_HOSTS": " api.ejemplo.com , otro.ejemplo.com ,",
            "CSRF_TRUSTED_ORIGINS": "https://api.ejemplo.com",
        })
        self.assertEqual(c["ALLOWED_HOSTS"], ["api.ejemplo.com", "otro.ejemplo.com"])
        self.assertEqual(c["CSRF_TRUSTED_ORIGINS"], ["https://api.ejemplo.com"])

    def test_la_clave_es_la_del_entorno(self):
        self.assertEqual(configuracion(**SERVIDOR)["SECRET_KEY"], SERVIDOR["SECRET_KEY"])

    def test_numero_de_proxies(self):
        self.assertEqual(configuracion(**SERVIDOR)["NUM_PROXIES_CONFIABLES"], 0)
        self.assertEqual(configuracion(**SERVIDOR, NUM_PROXIES_CONFIABLES="1")["NUM_PROXIES_CONFIABLES"], 1)
        codigo, salida = arrancar(**SERVIDOR, NUM_PROXIES_CONFIABLES="uno")
        self.assertNotEqual(codigo, 0)
        self.assertIn("NUM_PROXIES_CONFIABLES", salida)

    def test_base_cifrada_para_rds(self):
        c = configuracion(**SERVIDOR, DB_ENGINE="postgresql", DB_SSLMODE="require", DB_CONN_MAX_AGE="60")
        self.assertEqual((c["DB_OPTIONS"], c["CONN_MAX_AGE"]), ({"sslmode": "require"}, 60))

    def test_base_local_sin_ssl(self):
        c = configuracion(**SERVIDOR, DB_ENGINE="postgresql")
        self.assertEqual((c["DB_OPTIONS"], c["CONN_MAX_AGE"]), ({}, 0))


class DesarrolloTests(SimpleTestCase):
    def test_con_debug_arranca_sin_clave_ni_hosts(self):
        c = configuracion(DEBUG="true")
        self.assertTrue(c["DEBUG"])
        self.assertEqual(c["SECRET_KEY"], "solo-para-desarrollo-nunca-en-el-servidor")
        # Cualquier IP de tu computadora sirve para el teléfono.
        self.assertEqual(c["ALLOWED_HOSTS"], ["*"])
        self.assertFalse(c["SECURE_SSL_REDIRECT"])

    def test_un_valor_de_debug_que_no_se_entiende_falla_en_voz_alta(self):
        codigo, salida = arrancar(DEBUG="tal vez")
        self.assertNotEqual(codigo, 0)
        self.assertIn("DEBUG tiene que ser", salida)


class SinSecretosEnElCodigoTests(SimpleTestCase):
    def test_la_clave_vieja_ya_no_esta_en_settings(self):
        texto = (BACKEND / "config" / "settings.py").read_text(encoding="utf-8")
        self.assertNotIn("django-insecure-", texto)
        self.assertNotIn("172.20.10.3", texto)
