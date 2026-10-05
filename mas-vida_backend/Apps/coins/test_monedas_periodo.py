"""GET /api/v1/monedas/periodo (etapa 13, 4 oct 2026)."""
from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.coins.models import MonedaLedger
from Apps.coins.test_premios import crear_usuario, preparar_version_de_reglas
from services import monedas
from services.tiempo import hoy

OBJETIVO = MonedaLedger.Tipo.OBJETIVO_CUMPLIDO
LIGA = MonedaLedger.Tipo.LIGA_MENSUAL
AJUSTE = MonedaLedger.Tipo.AJUSTE_MANUAL

URL = "/api/v1/monedas/periodo"


def ajuste(usuario, cantidad, fecha):
    from services.reglas import version_regla_vigente
    return MonedaLedger.objects.create(
        usuario=usuario, cantidad=cantidad, tipo=AJUSTE, fecha=fecha,
        version_regla=version_regla_vigente(fecha),
    )


class ResumenDePeriodoTests(TestCase):
    """Con `hoy` explícito para que no dependa del reloj. Octubre de 2026 es de la season 4."""

    def setUp(self):
        preparar_version_de_reglas()
        self.ana = crear_usuario("ana")
        self.hoy = date(2026, 10, 30)

    def resumen(self, desde, hasta, usuario=None):
        return monedas.resumen_de_periodo(usuario or self.ana, desde, hasta, hoy=self.hoy)

    def test_un_periodo_sin_movimientos_es_todo_cero(self):
        self.assertEqual(self.resumen(date(2026, 10, 1), date(2026, 10, 31)), {
            "desde": "2026-10-01", "hasta": "2026-10-31", "ganadas": 0, "por_objetivos": 0,
            "por_liga": 0, "otras": 0, "gastadas": 0, "vencidas": 0, "anuladas": 0,
        })

    def test_separa_lo_ganado_por_objetivos_y_por_liga(self):
        monedas.acreditar(self.ana, 5, OBJETIVO, fecha=date(2026, 10, 6))
        monedas.acreditar(self.ana, 5, OBJETIVO, fecha=date(2026, 10, 13))
        monedas.acreditar(self.ana, 30, LIGA, fecha=date(2026, 10, 20))
        r = self.resumen(date(2026, 10, 1), date(2026, 10, 31))
        self.assertEqual((r["ganadas"], r["por_objetivos"], r["por_liga"]), (40, 10, 30))

    def test_gastadas_son_los_canjes_en_positivo(self):
        monedas.acreditar(self.ana, 50, LIGA, fecha=date(2026, 10, 6))
        monedas.gastar(self.ana, 40, fecha=date(2026, 10, 8))
        r = self.resumen(date(2026, 10, 1), date(2026, 10, 31))
        self.assertEqual((r["ganadas"], r["gastadas"]), (50, 40))

    def test_los_ajustes_a_favor_van_en_otras_y_en_contra_en_anuladas(self):
        monedas.acreditar(self.ana, 20, OBJETIVO, fecha=date(2026, 10, 6))
        ajuste(self.ana, 4, date(2026, 10, 7))
        ajuste(self.ana, -3, date(2026, 10, 8))
        r = self.resumen(date(2026, 10, 1), date(2026, 10, 31))
        self.assertEqual((r["ganadas"], r["otras"], r["anuladas"]), (24, 4, 3))

    def test_ganadas_siempre_es_la_suma_de_sus_partes(self):
        monedas.acreditar(self.ana, 5, OBJETIVO, fecha=date(2026, 10, 6))
        monedas.acreditar(self.ana, 30, LIGA, fecha=date(2026, 10, 7))
        ajuste(self.ana, 2, date(2026, 10, 8))
        r = self.resumen(date(2026, 10, 1), date(2026, 10, 31))
        self.assertEqual(r["ganadas"], r["por_objetivos"] + r["por_liga"] + r["otras"])

    def test_solo_cuenta_lo_que_cae_dentro_del_periodo_incluidos_los_dos_extremos(self):
        for dia in (date(2026, 9, 30), date(2026, 10, 1), date(2026, 10, 7), date(2026, 10, 8)):
            monedas.acreditar(self.ana, 1, OBJETIVO, fecha=dia)
        self.assertEqual(self.resumen(date(2026, 10, 1), date(2026, 10, 7))["ganadas"], 2)

    def test_un_dia_suelto_es_un_periodo_valido(self):
        monedas.acreditar(self.ana, 7, OBJETIVO, fecha=date(2026, 10, 6))
        self.assertEqual(self.resumen(date(2026, 10, 6), date(2026, 10, 6))["ganadas"], 7)

    def test_no_se_mezcla_con_las_monedas_de_otra_persona(self):
        beto = crear_usuario("beto")
        monedas.acreditar(beto, 99, OBJETIVO, fecha=date(2026, 10, 6))
        monedas.acreditar(self.ana, 5, OBJETIVO, fecha=date(2026, 10, 6))
        self.assertEqual(self.resumen(date(2026, 10, 1), date(2026, 10, 31))["ganadas"], 5)

    def test_las_vencidas_se_asientan_al_consultar_con_la_fecha_de_ese_dia(self):
        # 5 monedas de la season 3 (cerró el 27 de septiembre) que nadie gastó.
        monedas.acreditar(self.ana, 5, OBJETIVO, fecha=date(2026, 9, 10))
        antes = MonedaLedger.objects.filter(tipo=MonedaLedger.Tipo.EXPIRACION).count()
        self.assertEqual(antes, 0)

        r = self.resumen(date(2026, 10, 1), date(2026, 10, 31))
        self.assertEqual((r["vencidas"], r["ganadas"]), (5, 0))
        fila = MonedaLedger.objects.get(tipo=MonedaLedger.Tipo.EXPIRACION)
        self.assertEqual((fila.cantidad, fila.fecha), (-5, self.hoy))
        # Consultar otra vez no vuelve a vencer nada.
        self.assertEqual(self.resumen(date(2026, 10, 1), date(2026, 10, 31))["vencidas"], 5)
        self.assertEqual(MonedaLedger.objects.filter(tipo=MonedaLedger.Tipo.EXPIRACION).count(), 1)

    def test_las_vencidas_no_cuentan_en_un_periodo_donde_no_se_asentaron(self):
        monedas.acreditar(self.ana, 5, OBJETIVO, fecha=date(2026, 9, 10))
        self.assertEqual(self.resumen(date(2026, 9, 1), date(2026, 9, 30))["vencidas"], 0)

    def test_ganadas_menos_lo_que_sale_es_la_variacion_del_saldo(self):
        monedas.acreditar(self.ana, 30, LIGA, fecha=date(2026, 10, 6))
        monedas.acreditar(self.ana, 10, OBJETIVO, fecha=date(2026, 10, 7))
        monedas.gastar(self.ana, 25, fecha=date(2026, 10, 8))
        ajuste(self.ana, -2, date(2026, 10, 9))
        r = self.resumen(date(2026, 10, 1), date(2026, 10, 31))
        self.assertEqual(
            r["ganadas"] - r["gastadas"] - r["vencidas"] - r["anuladas"],
            monedas.saldo(self.ana, self.hoy),
        )


class MonedasPeriodoEndpointTests(APITestCase):
    def setUp(self):
        preparar_version_de_reglas()
        self.usuario = crear_usuario("ana")
        token = Token.objects.get(user=self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def pedir(self, **params):
        return self.client.get(URL, params)

    def test_pide_token(self):
        self.client.credentials()
        self.assertEqual(self.pedir(desde="2026-10-01", hasta="2026-10-31").status_code, 401)

    def test_cuenta_sin_perfil_da_403(self):
        user = get_user_model().objects.create_user("sinperfil", password="clave-segura-1")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=user).key}")
        self.assertEqual(self.pedir(desde="2026-10-01", hasta="2026-10-31").status_code, 403)

    def test_devuelve_el_resumen_del_periodo(self):
        monedas.acreditar(self.usuario, 5, OBJETIVO, fecha=hoy())
        monedas.acreditar(self.usuario, 30, LIGA, fecha=hoy())
        r = self.pedir(desde=(hoy() - timedelta(days=30)).isoformat(), hasta=hoy().isoformat())
        self.assertEqual(r.status_code, 200, r.content)
        datos = r.json()
        self.assertEqual(
            {k: datos[k] for k in ("ganadas", "por_objetivos", "por_liga", "otras", "gastadas", "vencidas", "anuladas")},
            {"ganadas": 35, "por_objetivos": 5, "por_liga": 30, "otras": 0, "gastadas": 0, "vencidas": 0, "anuladas": 0},
        )

    def test_desde_y_hasta_son_obligatorios(self):
        self.assertEqual(self.pedir(hasta="2026-10-31").status_code, 400)
        self.assertEqual(self.pedir(desde="2026-10-01").status_code, 400)
        self.assertEqual(self.pedir().status_code, 400)

    def test_formato_de_fecha_invalido(self):
        for malo in ("01/10/2026", "2026-13-01", "hoy"):
            with self.subTest(malo=malo):
                self.assertEqual(self.pedir(desde=malo, hasta="2026-10-31").status_code, 400)

    def test_desde_no_puede_ser_mayor_que_hasta(self):
        self.assertEqual(self.pedir(desde="2026-10-31", hasta="2026-10-01").status_code, 400)

    def test_el_rango_no_pasa_de_un_anio_con_bisiesto(self):
        self.assertEqual(self.pedir(desde="2026-01-01", hasta="2027-01-01").status_code, 200)
        self.assertEqual(self.pedir(desde="2026-01-01", hasta="2027-01-02").status_code, 400)

    def test_no_se_ven_las_monedas_de_otra_persona(self):
        beto = crear_usuario("beto")
        monedas.acreditar(beto, 80, LIGA, fecha=hoy())
        datos = self.pedir(desde=hoy().isoformat(), hasta=hoy().isoformat()).json()
        self.assertEqual(datos["ganadas"], 0)
