"""Un cupón dura 3 semanas, canjeado o ganado (etapa 12, 6 oct 2026)."""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from django.test import TestCase

from Apps.coins.models import Canje, MonedaLedger, Patrocinio
from Apps.coins.test_premios import crear_cupon, crear_premio, crear_usuario, preparar_version_de_reglas, verificar
from services import monedas, premios
from services.tiempo import hoy

GT = ZoneInfo("America/Guatemala")


class DuracionDelCuponTests(TestCase):
    def setUp(self):
        preparar_version_de_reglas()
        self.usuario = crear_usuario()
        verificar(self.usuario)
        self.premio = crear_premio(costo=40)

    def test_la_constante_es_de_21_dias(self):
        self.assertEqual(premios.DIAS_DE_UN_CUPON, 21)

    def test_canjeado_con_monedas_vence_a_los_21_dias(self):
        monedas.acreditar(self.usuario, 100, MonedaLedger.Tipo.OBJETIVO_CUMPLIDO, fecha=hoy())
        canje = premios.canjear(self.usuario, self.premio)
        self.assertEqual(canje.fecha_expiracion_cupon, hoy() + timedelta(days=21))

    def test_ganado_de_un_patrocinio_vence_a_los_21_dias(self):
        patrocinio = Patrocinio.objects.create(
            tipo=Patrocinio.Tipo.SEMANA, desde=date(2026, 9, 21), hasta=date(2026, 9, 27),
            premio=self.premio, cupon="2x1",
        )
        ahora = datetime(2026, 9, 29, 0, 5, tzinfo=GT)
        canje = premios.ganar_cupon(self.usuario, patrocinio, Canje.Origen.SEMANA, "Semana 1", ahora)
        self.assertEqual(canje.fecha_expiracion_cupon, date(2026, 10, 20))

    def test_el_dia_21_todavia_sirve_y_el_22_ya_no(self):
        canje = crear_cupon(self.usuario, self.premio, dias_para_vencer=21)
        self.assertEqual(premios.estado_de(canje, hoy() + timedelta(days=21)), premios.ACTIVO)
        self.assertEqual(premios.estado_de(canje, hoy() + timedelta(days=22)), premios.VENCIDO)

    def test_el_cupon_se_cuenta_desde_el_dia_de_guatemala_no_el_de_utc(self):
        # 29 sep 20:00 en Guatemala ya es 30 sep en UTC: cuenta el día de Guatemala.
        patrocinio = Patrocinio.objects.create(
            tipo=Patrocinio.Tipo.SEMANA, desde=date(2026, 9, 21), hasta=date(2026, 9, 27),
            premio=self.premio, cupon="2x1",
        )
        ahora = datetime(2026, 9, 29, 20, 0, tzinfo=GT)
        canje = premios.ganar_cupon(self.usuario, patrocinio, Canje.Origen.SEMANA, "Semana 1", ahora)
        self.assertEqual(canje.fecha_expiracion_cupon, date(2026, 10, 20))

    def test_un_cupon_ya_emitido_con_60_dias_conserva_su_fecha(self):
        viejo = crear_cupon(self.usuario, self.premio, dias_para_vencer=55)
        self.assertEqual(premios.estado_de(viejo), premios.ACTIVO)
        viejo.refresh_from_db()
        self.assertEqual(viejo.fecha_expiracion_cupon, hoy() + timedelta(days=55))
