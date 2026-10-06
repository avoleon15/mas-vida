"""GET /api/v1/perfil (etapa 13, 4 oct 2026)."""
from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework.test import APITestCase

from Apps.activities.models import Muestra, MuestraBPM, Sesion
from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario
from Apps.users.pruebas import token_de
from services import perfil

User = get_user_model()
URL = "/api/v1/perfil"
VERIFICADA = PolizaVinculada.EstadoVerificacion.VERIFICADA
PENDIENTE = PolizaVinculada.EstadoVerificacion.PENDIENTE

WATCH = {
    "fuente_bundle": "com.apple.health", "fuente_nombre": "Apple Watch",
    "dispositivo_nombre": "Apple Watch de Ana", "dispositivo_modelo": "Watch",
    "dispositivo_fabricante": "Apple Inc.",
}
IPHONE = {
    "fuente_bundle": "com.apple.health", "fuente_nombre": "iPhone",
    "dispositivo_nombre": "iPhone de Ana", "dispositivo_modelo": "iPhone",
    "dispositivo_fabricante": "Apple Inc.",
}
GARMIN = {
    "fuente_bundle": "com.garmin.connect", "fuente_nombre": "Garmin Connect",
    "dispositivo_nombre": None, "dispositivo_modelo": None, "dispositivo_fabricante": "Garmin",
}


def crear(username="ana@correo.com", nacimiento=date(1990, 5, 17), **extra):
    user = User.objects.create_user(username, password="clave-segura-1", **extra)
    return Usuario.objects.create(user=user, usuario_id=f"id-{user.pk}", birth_date=nacimiento)


def poliza(usuario, estado=VERIFICADA, **extra):
    datos = dict(
        policy_number=f"P-{usuario.pk}", insurer="Demo", estado_verificacion=estado,
        nombre="Ana", apellido="Martínez",
    )
    datos.update(extra)
    return PolizaVinculada.objects.create(usuario=usuario, **datos)


def pasos(usuario, dispositivo, hace_dias, externo):
    inicio = timezone.now() - timedelta(days=hace_dias)
    return Muestra.objects.create(
        usuario=usuario, external_id=externo, inicio=inicio, fin=inicio + timedelta(minutes=30),
        cantidad=500, **dispositivo,
    )


class _ConToken:
    def setUp(self):
        self.usuario = crear()
        token = token_de(self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token}")

    def get(self):
        r = self.client.get(URL)
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()


class PerfilEndpointTests(_ConToken, APITestCase):
    def test_pide_token(self):
        self.client.credentials()
        self.assertEqual(self.client.get(URL).status_code, 401)

    def test_una_cuenta_sin_perfil_da_403(self):
        user = User.objects.create_user("sinperfil", password="clave-segura-1")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(user)}")
        self.assertEqual(self.client.get(URL).status_code, 403)

    def test_solo_acepta_get(self):
        self.assertEqual(self.client.post(URL).status_code, 405)

    def test_cuenta_base_sin_poliza(self):
        datos = self.get()
        self.assertEqual(set(datos), {
            "usuario_id", "correo", "nombre", "fecha_nacimiento", "edad",
            "poliza_verificada", "dispositivos",
        })
        self.assertEqual(datos["usuario_id"], self.usuario.usuario_id)
        self.assertEqual(datos["correo"], "ana@correo.com")
        self.assertIsNone(datos["nombre"])
        self.assertEqual(datos["fecha_nacimiento"], "1990-05-17")
        self.assertIs(datos["poliza_verificada"], False)
        self.assertEqual(datos["dispositivos"], [])

    def test_no_devuelve_nada_de_otra_persona_ni_de_la_contrasena(self):
        otra = crear("beto@correo.com")
        poliza(otra, nombre="Beto", apellido="Ramírez")
        texto = str(self.get())
        self.assertNotIn("Beto", texto)
        self.assertNotIn("beto@correo.com", texto)
        self.assertNotIn("password", texto)

    def test_con_poliza_verificada_trae_el_nombre_y_la_fecha_de_la_aseguradora(self):
        poliza(self.usuario, birth_date_confirmada=date(1990, 5, 20))
        datos = self.get()
        self.assertEqual(datos["nombre"], "Ana Martínez")
        self.assertEqual(datos["fecha_nacimiento"], "1990-05-20")
        self.assertIs(datos["poliza_verificada"], True)

    def test_pendiente_o_rechazada_se_ve_como_sin_poliza(self):
        for estado in (PENDIENTE, PolizaVinculada.EstadoVerificacion.RECHAZADA):
            with self.subTest(estado=estado):
                PolizaVinculada.objects.all().delete()
                poliza(self.usuario, estado, birth_date_confirmada=date(1990, 5, 20))
                datos = self.get()
                self.assertIsNone(datos["nombre"])
                self.assertIs(datos["poliza_verificada"], False)
                self.assertEqual(datos["fecha_nacimiento"], "1990-05-17")


class EdadYCorreoTests(APITestCase):
    def test_la_edad_cumple_anios_ese_dia(self):
        usuario = crear(nacimiento=date(1990, 5, 17))
        self.assertEqual(perfil.resumen(usuario, hoy=date(2026, 5, 16))["edad"], 35)
        self.assertEqual(perfil.resumen(usuario, hoy=date(2026, 5, 17))["edad"], 36)

    def test_la_edad_es_la_de_la_aseguradora_si_hay_poliza_verificada(self):
        usuario = crear(nacimiento=date(1990, 5, 17))
        poliza(usuario, birth_date_confirmada=date(1960, 1, 1))
        self.assertEqual(perfil.resumen(usuario, hoy=date(2026, 10, 4))["edad"], 66)

    def test_correo_de_cuenta_con_contrasena_es_el_username(self):
        self.assertEqual(perfil.correo_de(crear("ana@correo.com").user), "ana@correo.com")

    def test_correo_de_cuenta_social_es_el_email_guardado(self):
        usuario = crear("google-4f2a9c1d", email="ana@gmail.com")
        self.assertEqual(perfil.correo_de(usuario.user), "ana@gmail.com")

    def test_un_username_generado_no_es_un_correo(self):
        self.assertIsNone(perfil.correo_de(crear("apple-4f2a9c1d").user))

    def test_el_email_guardado_manda_sobre_el_username(self):
        usuario = crear("ana@viejo.com", email="ana@nuevo.com")
        self.assertEqual(perfil.correo_de(usuario.user), "ana@nuevo.com")


class DispositivosTests(_ConToken, APITestCase):
    def test_lista_los_que_mandaron_datos_en_los_ultimos_30_dias(self):
        pasos(self.usuario, WATCH, 2, "w1")
        pasos(self.usuario, IPHONE, 1, "i1")
        dispositivos = self.get()["dispositivos"]
        self.assertEqual([d["nombre"] for d in dispositivos], ["iPhone de Ana", "Apple Watch de Ana"])
        self.assertEqual(dispositivos[0], {
            "nombre": "iPhone de Ana", "modelo": "iPhone", "fuente": "iPhone",
            "ultimo_dato": (timezone.localdate() - timedelta(days=1)).isoformat(),
        })

    def test_uno_que_ya_no_manda_datos_sale_de_la_lista(self):
        pasos(self.usuario, WATCH, 40, "w-viejo")
        pasos(self.usuario, IPHONE, 3, "i1")
        self.assertEqual([d["nombre"] for d in self.get()["dispositivos"]], ["iPhone de Ana"])

    def test_el_limite_son_30_dias(self):
        pasos(self.usuario, WATCH, 29, "w1")
        pasos(self.usuario, IPHONE, 31, "i1")
        self.assertEqual([d["nombre"] for d in self.get()["dispositivos"]], ["Apple Watch de Ana"])

    def test_un_dispositivo_que_manda_pasos_ritmo_y_workouts_sale_una_sola_vez(self):
        pasos(self.usuario, WATCH, 5, "w-pasos")
        inicio = timezone.now() - timedelta(days=1)
        MuestraBPM.objects.create(
            usuario=self.usuario, external_id="w-bpm", inicio=inicio, fin=inicio, bpm=120, **WATCH,
        )
        Sesion.objects.create(
            usuario=self.usuario, external_id="w-sesion", inicio=inicio, fin=inicio + timedelta(minutes=40),
            duracion_min=40, tipo_actividad="running", fc_promedio=140, fc_maxima=160, **WATCH,
        )
        dispositivos = self.get()["dispositivos"]
        self.assertEqual(len(dispositivos), 1)
        # El último dato es el más nuevo de las tres tablas (ayer, no hace 5 días).
        self.assertEqual(dispositivos[0]["ultimo_dato"], (timezone.localdate() - timedelta(days=1)).isoformat())

    def test_sin_nombre_de_dispositivo_se_usa_el_de_la_fuente(self):
        pasos(self.usuario, GARMIN, 2, "g1")
        garmin = self.get()["dispositivos"][0]
        self.assertEqual(garmin["nombre"], "Garmin Connect")
        self.assertIsNone(garmin["modelo"])

    def test_no_se_ven_los_dispositivos_de_otra_persona(self):
        otra = crear("beto@correo.com")
        pasos(otra, WATCH, 1, "otro-w")
        self.assertEqual(self.get()["dispositivos"], [])

    def test_el_mismo_dispositivo_con_otro_nombre_gana_el_dato_mas_nuevo(self):
        pasos(self.usuario, WATCH, 10, "w-viejo")
        renombrado = {**WATCH, "dispositivo_nombre": "Reloj de Ana"}
        pasos(self.usuario, renombrado, 1, "w-nuevo")
        dispositivos = self.get()["dispositivos"]
        self.assertEqual([d["nombre"] for d in dispositivos], ["Reloj de Ana"])
