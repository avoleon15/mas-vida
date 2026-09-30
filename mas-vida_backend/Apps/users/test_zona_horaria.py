"""La zona horaria del proyecto es la de Guatemala (UTC-6, sin horario de verano).

Importa porque "hoy" cambia de día a las 00:00 de Guatemala (06:00 UTC), no a
las 00:00 UTC: entre las 18:00 y la medianoche de Guatemala, UTC ya está en el
día siguiente.
"""
import datetime
from datetime import timezone as tz
from unittest import mock

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase
from django.utils import timezone
from rest_framework.test import APITestCase

from Apps.users.models import Usuario


def a_las(anio, mes, dia, hora, minuto=0, segundo=0):
    """Un instante, dado en UTC."""
    return datetime.datetime(anio, mes, dia, hora, minuto, segundo, tzinfo=tz.utc)


def ahora_es(instante):
    return mock.patch("django.utils.timezone.now", return_value=instante)


class ConfiguracionTests(SimpleTestCase):
    def test_la_zona_es_la_de_guatemala(self):
        self.assertEqual(settings.TIME_ZONE, "America/Guatemala")

    def test_las_fechas_con_hora_siguen_siendo_conscientes_de_la_zona(self):
        # Sin USE_TZ las horas se guardarían "a ojo" y se mezclarían.
        self.assertTrue(settings.USE_TZ)


class HoyLocalTests(SimpleTestCase):
    def test_a_las_23_de_guatemala_todavia_es_el_mismo_dia(self):
        # 23:00 del 30-sep en Guatemala = 05:00 UTC del 1-oct.
        with ahora_es(a_las(2026, 10, 1, 5, 0)):
            self.assertEqual(timezone.localdate(), datetime.date(2026, 9, 30))

    def test_el_dia_cambia_a_medianoche_de_guatemala_no_de_utc(self):
        with ahora_es(a_las(2026, 10, 1, 5, 59, 59)):
            antes = timezone.localdate()
        with ahora_es(a_las(2026, 10, 1, 6, 0, 0)):
            despues = timezone.localdate()

        self.assertEqual(antes, datetime.date(2026, 9, 30))
        self.assertEqual(despues, datetime.date(2026, 10, 1))

    def test_a_medianoche_utc_en_guatemala_es_la_tarde_del_dia_anterior(self):
        with ahora_es(a_las(2026, 10, 1, 0, 0)):
            self.assertEqual(timezone.localdate(), datetime.date(2026, 9, 30))

    def test_la_hora_local_va_seis_horas_atras_de_utc(self):
        local = timezone.localtime(a_las(2026, 6, 15, 12, 0))

        self.assertEqual((local.hour, local.day), (6, 15))
        self.assertEqual(local.utcoffset(), datetime.timedelta(hours=-6))

    def test_no_hay_horario_de_verano(self):
        # En enero y en julio el desfase es el mismo.
        enero = timezone.localtime(a_las(2026, 1, 15, 12, 0)).utcoffset()
        julio = timezone.localtime(a_las(2026, 7, 15, 12, 0)).utcoffset()

        self.assertEqual(enero, julio)


class RegistroFechaFuturaTests(APITestCase):
    """El registro rechaza fechas de nacimiento futuras según el día de Guatemala."""

    url = "/api/v1/registro"

    def registrar(self, nombre, nacimiento):
        return self.client.post(
            self.url,
            {"username": nombre, "password": "Clave-segura-2026", "birth_date": nacimiento},
            format="json",
        )

    def test_a_las_23_de_guatemala_manana_es_futuro(self):
        # 23:00 del 30-sep en Guatemala: el 1-oct todavía no llega.
        with ahora_es(a_las(2026, 10, 1, 5, 0)):
            respuesta = self.registrar("ana", "2026-10-01")

        self.assertEqual(respuesta.status_code, 400)
        self.assertIn("birth_date", respuesta.json())

    def test_a_las_23_de_guatemala_hoy_es_valido(self):
        with ahora_es(a_las(2026, 10, 1, 5, 0)):
            respuesta = self.registrar("ana", "2026-09-30")

        self.assertEqual(respuesta.status_code, 201)

    def test_pasada_la_medianoche_de_guatemala_el_nuevo_dia_ya_es_valido(self):
        with ahora_es(a_las(2026, 10, 1, 6, 0)):
            respuesta = self.registrar("ana", "2026-10-01")

        self.assertEqual(respuesta.status_code, 201)


class FechasConHoraTests(TestCase):
    """Cambiar de zona no mueve ni reinterpreta lo ya guardado."""

    def test_una_fecha_con_hora_conserva_el_mismo_instante(self):
        from Apps.poincs.models import Ledger, VersionRegla

        user = get_user_model().objects.create_user("ana", password="x")
        usuario = Usuario.objects.create(
            user=user, usuario_id="id-ana", birth_date=datetime.date(1990, 1, 1)
        )
        version = VersionRegla.objects.create(version=1, vigente_desde=datetime.date(2026, 1, 1))

        with ahora_es(a_las(2026, 10, 1, 5, 0)):
            ledger = Ledger.objects.create(
                usuario=usuario, puntos=10, tipo="pasos",
                fecha=datetime.date(2026, 9, 30), version_regla=version,
            )
        ledger.refresh_from_db()

        self.assertEqual(ledger.creado_en, a_las(2026, 10, 1, 5, 0))
        # Se guarda en UTC y se lee en hora de Guatemala: es el mismo instante.
        self.assertEqual(timezone.localtime(ledger.creado_en).hour, 23)
