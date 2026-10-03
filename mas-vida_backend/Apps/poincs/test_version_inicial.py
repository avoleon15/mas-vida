from datetime import date
from importlib import import_module

from django.apps import apps as apps_reales
from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.poincs.models import VersionRegla
from Apps.users.models import Usuario

migracion = import_module("Apps.poincs.migrations.0007_version_regla_inicial")
migracion_v2 = import_module("Apps.poincs.migrations.0008_version_regla_2_oct")


class VersionInicialTests(TestCase):
    """La migración 0007 deja cargada la versión 1 de las reglas."""

    def test_tras_migrar_existe_la_version_1(self):
        version = VersionRegla.objects.get(version=1)
        self.assertEqual(version.vigente_desde, date(2026, 1, 1))

    def test_hay_dos_versiones_la_1_y_la_de_la_reunion_del_2_oct(self):
        self.assertEqual(
            list(VersionRegla.objects.order_by("version").values_list("version", "vigente_desde")),
            [(1, date(2026, 1, 1)), (2, date(2026, 10, 2))],
        )

    def test_correrla_de_nuevo_no_la_duplica(self):
        migracion.crear_version_inicial(apps_reales, None)
        migracion.crear_version_inicial(apps_reales, None)
        self.assertEqual(VersionRegla.objects.filter(version=1).count(), 1)

    def test_no_pisa_una_version_1_que_ya_existia(self):
        VersionRegla.objects.filter(version=1).update(vigente_desde=date(2025, 6, 1))
        migracion.crear_version_inicial(apps_reales, None)
        self.assertEqual(VersionRegla.objects.get(version=1).vigente_desde, date(2025, 6, 1))

    def test_esta_vigente_para_la_ventana_de_sync(self):
        # La ventana de datos rezagados es de 14 días: todo eso debe tener versión.
        from services.reglas import version_regla_vigente

        hoy = timezone.localdate()
        esperada = 2 if hoy >= date(2026, 10, 2) else 1
        self.assertEqual(version_regla_vigente(hoy).version, esperada)
        self.assertEqual(version_regla_vigente(date(2026, 1, 1)).version, 1)


class SyncConBaseRecienCreadaTests(APITestCase):
    """Lo que antes respondía 500: un sync sin haber cargado nada a mano."""

    def test_el_primer_sync_funciona_sin_cargar_nada(self):
        user = User.objects.create_user(username="ana", password="clave-segura-1")
        Usuario.objects.create(user=user, usuario_id="ana-1", birth_date=date(1990, 1, 1))
        token = Token.objects.get(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

        hoy = timezone.localdate().isoformat()
        r = self.client.post("/api/v1/sync", {
            "fecha": hoy,
            "zona_horaria": "America/Guatemala",
            "sincronizado_en": f"{hoy}T20:00:00-06:00",
            "app_version": "1.0.0",
            "pasos": [{
                "external_id": "a1",
                "inicio": f"{hoy}T08:00:00-06:00",
                "fin": f"{hoy}T08:30:00-06:00",
                "cantidad": 12000,
                "fuente_bundle": "com.apple.health",
                "fuente_nombre": "Salud",
                "dispositivo_modelo": "iPhone",
            }],
        }, format="json")

        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["puntos_pasos"], 50)


class VersionDosTests(TestCase):
    """La versión 2 (reglas del 2 oct 2026) y cómo sella las filas."""

    def test_el_dia_anterior_sigue_siendo_la_version_1(self):
        from services.reglas import version_regla_vigente

        self.assertEqual(version_regla_vigente(date(2026, 10, 1)).version, 1)

    def test_desde_el_2_de_octubre_rige_la_version_2(self):
        from services.reglas import version_regla_vigente

        for dia in (date(2026, 10, 2), date(2026, 12, 31), date(2027, 6, 1)):
            self.assertEqual(version_regla_vigente(dia).version, 2, dia)

    def test_correrla_de_nuevo_no_la_duplica_ni_la_pisa(self):
        VersionRegla.objects.filter(version=2).update(vigente_desde=date(2026, 11, 1))
        migracion_v2.crear_version(apps_reales, None)
        migracion_v2.crear_version(apps_reales, None)
        self.assertEqual(VersionRegla.objects.filter(version=2).count(), 1)
        self.assertEqual(VersionRegla.objects.get(version=2).vigente_desde, date(2026, 11, 1))

    def test_las_monedas_ganadas_antes_y_despues_quedan_selladas_distinto(self):
        from Apps.coins.models import MonedaLedger
        from services import monedas

        user = User.objects.create_user(username="ana", password="clave-segura-1")
        usuario = Usuario.objects.create(user=user, usuario_id="ana-1", birth_date=date(1990, 1, 1))
        monedas.acreditar(usuario, 5, "objetivo_cumplido", fecha=date(2026, 9, 30))
        monedas.acreditar(usuario, 5, "objetivo_cumplido", fecha=date(2026, 10, 2))

        versiones = list(
            MonedaLedger.objects.filter(usuario=usuario)
            .order_by("fecha").values_list("fecha", "version_regla__version")
        )
        self.assertEqual(versiones, [(date(2026, 9, 30), 1), (date(2026, 10, 2), 2)])
