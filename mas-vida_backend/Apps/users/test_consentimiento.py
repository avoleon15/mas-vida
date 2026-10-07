"""Consentimiento para compartir los datos con la aseguradora (etapa 14, 6 oct 2026)."""
import os
from datetime import date, datetime, timedelta
from unittest import mock
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.core.exceptions import ImproperlyConfigured
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from Apps.activities.models import Muestra
from Apps.poincs.models import VersionRegla
from Apps.users.models import Consentimiento, Usuario
from Apps.users.pruebas import token_de
from config import settings as ajustes
from services import consentimiento

User = get_user_model()
GT = ZoneInfo("America/Guatemala")
CLAVE = "Clave-segura-2026"


def crear_usuario(nombre="ana"):
    user = User.objects.create_user(f"{nombre}@correo.com", password=CLAVE)
    return Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=date(1990, 1, 1))


class ServicioTests(TestCase):
    def setUp(self):
        self.ana = crear_usuario()

    def test_al_inicio_no_hay_consentimiento(self):
        self.assertFalse(consentimiento.vigente(self.ana))
        estado = consentimiento.estado(self.ana)
        self.assertEqual(
            (estado["aceptado"], estado["version_aceptada"], estado["aceptado_en"], estado["revocado_en"]),
            (False, None, None, None),
        )
        self.assertEqual(estado["version_vigente"], consentimiento.VERSION_VIGENTE)

    def test_aceptar_guarda_cuando_y_que_version(self):
        ahora = datetime(2026, 10, 6, 9, 30, tzinfo=GT)
        self.assertTrue(consentimiento.aceptar(self.ana, consentimiento.VERSION_VIGENTE, ahora))
        fila = Consentimiento.objects.get(usuario=self.ana)
        self.assertEqual((fila.version, fila.aceptado_en, fila.revocado_en), ("1", ahora, None))
        self.assertTrue(consentimiento.vigente(self.ana))

    def test_aceptar_otra_vez_no_duplica(self):
        consentimiento.aceptar(self.ana, "1")
        self.assertFalse(consentimiento.aceptar(self.ana, "1"))
        self.assertEqual(Consentimiento.objects.filter(usuario=self.ana).count(), 1)

    def test_una_version_que_no_es_la_vigente_se_rechaza(self):
        with self.assertRaises(consentimiento.VersionDesactualizada) as error:
            consentimiento.aceptar(self.ana, "0")
        self.assertEqual(str(error.exception), "1")
        self.assertFalse(Consentimiento.objects.exists())

    def test_revocar_deja_de_ser_vigente_y_guarda_cuando(self):
        consentimiento.aceptar(self.ana, "1")
        ahora = datetime(2026, 10, 7, 8, 0, tzinfo=GT)
        self.assertEqual(consentimiento.revocar(self.ana, ahora), 1)
        self.assertFalse(consentimiento.vigente(self.ana))
        self.assertEqual(Consentimiento.objects.get(usuario=self.ana).revocado_en, ahora)
        self.assertEqual(consentimiento.estado(self.ana)["revocado_en"], ahora)

    def test_revocar_dos_veces_no_cambia_nada(self):
        consentimiento.aceptar(self.ana, "1")
        consentimiento.revocar(self.ana)
        self.assertEqual(consentimiento.revocar(self.ana), 0)

    def test_se_puede_volver_a_aceptar_y_el_historial_se_conserva(self):
        consentimiento.aceptar(self.ana, "1")
        consentimiento.revocar(self.ana)
        self.assertTrue(consentimiento.aceptar(self.ana, "1"))
        self.assertTrue(consentimiento.vigente(self.ana))
        self.assertEqual(Consentimiento.objects.filter(usuario=self.ana).count(), 2)
        self.assertEqual(Consentimiento.objects.filter(usuario=self.ana, revocado_en__isnull=True).count(), 1)

    def test_si_cambia_el_texto_lo_aceptado_antes_deja_de_valer(self):
        consentimiento.aceptar(self.ana, "1")
        with mock.patch.object(consentimiento, "VERSION_VIGENTE", "2"):
            self.assertFalse(consentimiento.vigente(self.ana))
            estado = consentimiento.estado(self.ana)
            self.assertEqual((estado["aceptado"], estado["version_aceptada"], estado["version_vigente"]), (False, "1", "2"))
            self.assertTrue(consentimiento.aceptar(self.ana, "2"))
            self.assertTrue(consentimiento.vigente(self.ana))

    def test_la_base_no_deja_dos_aceptaciones_vigentes_de_la_misma_version(self):
        from django.db import IntegrityError, transaction
        consentimiento.aceptar(self.ana, "1")
        with self.assertRaises(IntegrityError), transaction.atomic():
            Consentimiento.objects.create(usuario=self.ana, version="1")

    def test_cada_persona_tiene_el_suyo(self):
        beto = crear_usuario("beto")
        consentimiento.aceptar(self.ana, "1")
        self.assertFalse(consentimiento.vigente(beto))
        consentimiento.revocar(beto)
        self.assertTrue(consentimiento.vigente(self.ana))


class FiltroParaElReporteTests(TestCase):
    """`con_consentimiento_vigente`: quién puede entrar al reporte de la aseguradora."""

    def ids(self):
        consulta = consentimiento.con_consentimiento_vigente(Usuario.objects.all())
        return sorted(consulta.values_list("usuario_id", flat=True))

    def test_solo_entra_quien_lo_tiene_vigente(self):
        for nombre in ("acepto", "reboco", "nunca"):
            crear_usuario(nombre)
        consentimiento.aceptar(Usuario.objects.get(usuario_id="id-acepto"), "1")
        consentimiento.aceptar(Usuario.objects.get(usuario_id="id-reboco"), "1")
        consentimiento.revocar(Usuario.objects.get(usuario_id="id-reboco"))
        self.assertEqual(self.ids(), ["id-acepto"])

    def test_quien_acepto_un_texto_anterior_no_entra(self):
        ana = crear_usuario("ana")
        consentimiento.aceptar(ana, "1")
        with mock.patch.object(consentimiento, "VERSION_VIGENTE", "2"):
            self.assertEqual(self.ids(), [])

    def test_las_dos_condiciones_valen_para_la_misma_fila(self):
        # Una fila con la versión vigente PERO revocada y otra sin revocar de una versión vieja:
        # ninguna es vigente, aunque cada condición se cumpla en alguna fila.
        ana = crear_usuario("ana")
        Consentimiento.objects.create(usuario=ana, version="1", revocado_en=timezone.now())
        Consentimiento.objects.create(usuario=ana, version="0")
        self.assertEqual(self.ids(), [])

    def test_quien_tiene_varias_filas_sale_una_sola_vez(self):
        ana = crear_usuario("ana")
        consentimiento.aceptar(ana, "1")
        consentimiento.revocar(ana)
        consentimiento.aceptar(ana, "1")
        self.assertEqual(self.ids(), ["id-ana"])

    def test_se_puede_combinar_con_otros_filtros(self):
        crear_usuario("ana")
        crear_usuario("beto")
        for u in Usuario.objects.all():
            consentimiento.aceptar(u, "1")
        consulta = consentimiento.con_consentimiento_vigente(Usuario.objects.filter(usuario_id="id-beto"))
        self.assertEqual(list(consulta.values_list("usuario_id", flat=True)), ["id-beto"])


class EndpointTests(APITestCase):
    url = "/api/v1/consentimiento"

    def setUp(self):
        self.ana = crear_usuario()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(self.ana.user)}")

    def test_sin_token_pide_sesion(self):
        self.client.credentials()
        for metodo, url in (("get", self.url), ("post", self.url), ("post", self.url + "/revocar")):
            with self.subTest(url=url, metodo=metodo):
                self.assertEqual(getattr(self.client, metodo)(url).status_code, 401)

    def test_sin_perfil_responde_403(self):
        sin_perfil = User.objects.create_user("admin@correo.com", password=CLAVE)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(sin_perfil)}")
        for metodo, url in (("get", self.url), ("post", self.url), ("post", self.url + "/revocar")):
            with self.subTest(url=url):
                self.assertEqual(getattr(self.client, metodo)(url, {"version": "1"}, format="json").status_code, 403)

    def test_get_antes_de_aceptar(self):
        r = self.client.get(self.url)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json(), {
            "obligatorio": False, "version_vigente": "1", "aceptado": False,
            "version_aceptada": None, "aceptado_en": None, "revocado_en": None,
        })

    def test_aceptar(self):
        r = self.client.post(self.url, {"version": "1"}, format="json")
        self.assertEqual(r.status_code, 200, r.content)
        datos = r.json()
        self.assertEqual((datos["aceptado"], datos["version_aceptada"], datos["revocado_en"]), (True, "1", None))
        self.assertTrue(datos["aceptado_en"])
        self.assertEqual(self.client.get(self.url).json(), datos)

    def test_aceptar_dos_veces_es_igual_que_una(self):
        primero = self.client.post(self.url, {"version": "1"}, format="json").json()
        segundo = self.client.post(self.url, {"version": "1"}, format="json").json()
        self.assertEqual(primero, segundo)
        self.assertEqual(Consentimiento.objects.count(), 1)

    def test_una_version_vieja_responde_409_con_la_vigente(self):
        r = self.client.post(self.url, {"version": "0"}, format="json")
        self.assertEqual(r.status_code, 409)
        self.assertEqual(r.json(), {"error": "version_desactualizada", "version_vigente": "1"})
        self.assertFalse(Consentimiento.objects.exists())

    def test_sin_version_responde_400(self):
        for cuerpo in ({}, {"version": ""}, {"version": None}, {"version": 1}):
            with self.subTest(cuerpo=cuerpo):
                r = self.client.post(self.url, cuerpo, format="json")
                self.assertEqual(r.status_code, 400)
                self.assertIn("version", r.json())

    def test_revocar(self):
        self.client.post(self.url, {"version": "1"}, format="json")
        r = self.client.post(self.url + "/revocar")
        self.assertEqual(r.status_code, 200)
        datos = r.json()
        self.assertEqual((datos["aceptado"], datos["version_aceptada"]), (False, "1"))
        self.assertTrue(datos["revocado_en"])

    def test_revocar_sin_haber_aceptado_no_falla(self):
        r = self.client.post(self.url + "/revocar")
        self.assertEqual(r.status_code, 200)
        self.assertFalse(r.json()["aceptado"])

    def test_volver_a_aceptar_despues_de_revocar(self):
        self.client.post(self.url, {"version": "1"}, format="json")
        self.client.post(self.url + "/revocar")
        datos = self.client.post(self.url, {"version": "1"}, format="json").json()
        self.assertEqual((datos["aceptado"], datos["revocado_en"]), (True, None))

    def test_el_estado_dice_si_el_servidor_lo_exige(self):
        with override_settings(CONSENTIMIENTO_OBLIGATORIO=True):
            self.assertTrue(self.client.get(self.url).json()["obligatorio"])

    def test_nadie_ve_el_consentimiento_de_otro(self):
        beto = crear_usuario("beto")
        consentimiento.aceptar(beto, "1")
        self.assertFalse(self.client.get(self.url).json()["aceptado"])


class SyncTests(APITestCase):
    """Con el interruptor encendido, sin consentimiento vigente el sync no guarda nada."""

    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        self.ana = crear_usuario()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(self.ana.user)}")
        hoy = timezone.localdate()
        inicio = datetime(hoy.year, hoy.month, hoy.day, 8, 0, tzinfo=GT)
        self.cuerpo = {
            "fecha": hoy.isoformat(), "zona_horaria": "America/Guatemala",
            "sincronizado_en": inicio.isoformat(), "app_version": "1.0.0",
            "pasos": [{
                "external_id": "p1", "inicio": inicio.isoformat(),
                "fin": (inicio + timedelta(minutes=30)).isoformat(), "cantidad": 8000,
                "fuente_bundle": "com.apple.health", "fuente_nombre": "iPhone",
                "dispositivo_modelo": "iPhone", "dispositivo_fabricante": "Apple Inc.",
            }],
            "sesiones": [], "frecuencia_cardiaca": [],
        }

    def sync(self):
        return self.client.post("/api/v1/sync", self.cuerpo, format="json")

    def test_apagado_por_defecto_sincroniza_sin_consentimiento(self):
        self.assertEqual(self.sync().status_code, 200)
        self.assertEqual(Muestra.objects.count(), 1)

    @override_settings(CONSENTIMIENTO_OBLIGATORIO=True)
    def test_encendido_sin_consentimiento_responde_403_y_no_guarda_nada(self):
        r = self.sync()
        self.assertEqual(r.status_code, 403)
        self.assertEqual(r.json(), {"error": "consentimiento_requerido", "version": "1"})
        self.assertFalse(Muestra.objects.exists())

    @override_settings(CONSENTIMIENTO_OBLIGATORIO=True)
    def test_encendido_con_consentimiento_sincroniza(self):
        consentimiento.aceptar(self.ana, "1")
        self.assertEqual(self.sync().status_code, 200)
        self.assertEqual(Muestra.objects.count(), 1)

    @override_settings(CONSENTIMIENTO_OBLIGATORIO=True)
    def test_revocar_vuelve_a_cerrar_el_sync(self):
        consentimiento.aceptar(self.ana, "1")
        self.sync()
        consentimiento.revocar(self.ana)
        self.assertEqual(self.sync().status_code, 403)

    @override_settings(CONSENTIMIENTO_OBLIGATORIO=True)
    def test_un_texto_nuevo_pide_aceptar_otra_vez(self):
        consentimiento.aceptar(self.ana, "1")
        with mock.patch.object(consentimiento, "VERSION_VIGENTE", "2"):
            r = self.sync()
        self.assertEqual((r.status_code, r.json()["version"]), (403, "2"))

    @override_settings(CONSENTIMIENTO_OBLIGATORIO=True)
    def test_el_resto_de_la_api_sigue_funcionando_sin_consentimiento(self):
        # Solo se cierra el sync: la persona puede entrar, ver y aceptar.
        self.assertEqual(self.client.get("/api/v1/perfil").status_code, 200)
        self.assertEqual(self.client.get("/api/v1/historial").status_code, 200)
        self.assertEqual(self.client.get("/api/v1/consentimiento").status_code, 200)


class InterruptorTests(TestCase):
    def leer(self, valor):
        with mock.patch.dict(os.environ, {"CONSENTIMIENTO_OBLIGATORIO": valor}):
            return ajustes._bool_de_entorno("CONSENTIMIENTO_OBLIGATORIO")

    def test_apagado_si_no_se_define(self):
        with mock.patch.dict(os.environ, clear=False):
            os.environ.pop("CONSENTIMIENTO_OBLIGATORIO", None)
            self.assertFalse(ajustes._bool_de_entorno("CONSENTIMIENTO_OBLIGATORIO"))

    def test_valores_que_lo_encienden(self):
        for valor in ("1", "true", "TRUE", "si", "sí", "yes", "on", " Si "):
            with self.subTest(valor=valor):
                self.assertTrue(self.leer(valor))

    def test_valores_que_lo_apagan(self):
        for valor in ("", "0", "false", "no", "off"):
            with self.subTest(valor=valor):
                self.assertFalse(self.leer(valor))

    def test_un_valor_que_no_se_entiende_falla_en_voz_alta(self):
        with self.assertRaises(ImproperlyConfigured):
            self.leer("tal vez")

    def test_el_valor_de_los_ajustes_viene_apagado(self):
        self.assertFalse(ajustes.CONSENTIMIENTO_OBLIGATORIO)
