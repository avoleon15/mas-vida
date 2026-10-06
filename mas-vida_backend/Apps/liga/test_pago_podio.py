"""Por qué el podio se paga el día 9 y no el día 2 (etapa 12, 6 oct 2026)."""
from datetime import date

from django.test import SimpleTestCase, TestCase

from Apps.coins.models import MonedaLedger
from Apps.liga.test_ligas import CIERRE, OCTUBRE, PAGO, VERIFICADA, crear_usuario, puntos, version
from services import ligas, monedas
from services.tiempo import rango_season

# Los meses en que arranca una season: enero, abril, julio y octubre (semanas ISO 1, 14, 27 y 40).
MESES_DE_SEASON = (1, 4, 7, 10)
ANIOS = range(2026, 2046)


def siguiente_mes(anio, mes):
    return date(anio + (mes == 12), mes % 12 + 1, 1)


class DiaDePagoTests(SimpleTestCase):
    def test_el_pago_es_el_dia_9_del_mes_siguiente(self):
        self.assertEqual(ligas.DIA_DE_PAGO, 9)
        self.assertEqual(ligas.dia_de_pago(date(2026, 10, 1)), date(2026, 11, 9))
        self.assertEqual(ligas.dia_de_pago(date(2026, 12, 15)), date(2027, 1, 9))     # cruza el año
        self.assertEqual(ligas.dia_de_pago(date(2027, 1, 31)), date(2027, 2, 9))

    def test_el_pago_es_despues_del_cierre(self):
        for anio in ANIOS:
            for mes in range(1, 13):
                with self.subTest(anio=anio, mes=mes):
                    dia = date(anio, mes, 1)
                    self.assertGreater(ligas.dia_de_pago(dia), ligas.dia_de_cierre(dia))

    def test_el_dia_9_siempre_cae_en_la_season_nueva_con_casi_toda_su_vida_por_delante(self):
        # En los meses en que arranca una season, lo pagado el día 9 vive al menos 11 semanas.
        for anio in ANIOS:
            for mes in MESES_DE_SEASON:
                with self.subTest(anio=anio, mes=mes):
                    mes_de_la_liga = date(anio - (mes == 1), (mes - 2) % 12 + 1, 1)    # el mes anterior
                    pago = ligas.dia_de_pago(mes_de_la_liga)
                    self.assertEqual(pago, date(anio, mes, 9))
                    inicio, fin = rango_season(pago)
                    self.assertLessEqual(inicio, date(anio, mes, 5), "la season ya había arrancado")
                    self.assertGreaterEqual((fin - pago).days, 11 * 7)

    def test_el_dia_2_si_podia_caer_en_la_season_que_estaba_por_terminar(self):
        # Por eso se movió: hay años en que el día 2 queda en la season vieja (que vence a los pocos días).
        casos_malos = [
            (anio, mes)
            for anio in ANIOS for mes in MESES_DE_SEASON
            if (rango_season(date(anio, mes, 2))[1] - date(anio, mes, 2)).days < 7
        ]
        self.assertTrue(casos_malos, "ningún año tenía el problema que justifica el día 9")


class LasMonedasDelPagoDuranTests(TestCase):
    """Lo pagado el día 9 queda en la season de ese día, no en la del cierre."""

    def setUp(self):
        version()
        self.oro = crear_usuario("oro", VERIFICADA)
        puntos(self.oro, date(2026, 10, 15), 100)

    def test_las_monedas_vencen_con_la_season_del_dia_de_pago(self):
        ligas.cerrar_la_liga(OCTUBRE, CIERRE)
        ligas.pagar_la_liga(OCTUBRE, PAGO)
        fila = MonedaLedger.objects.get(usuario=self.oro)
        self.assertEqual(fila.fecha, PAGO)
        self.assertEqual(fila.fecha_expiracion, rango_season(PAGO)[1])

    def test_el_saldo_del_podio_sigue_vivo_semanas_despues(self):
        ligas.cerrar_la_liga(OCTUBRE, CIERRE)
        ligas.pagar_la_liga(OCTUBRE, PAGO)
        self.assertEqual(monedas.saldo(self.oro, date(2026, 12, 20)), 30)
