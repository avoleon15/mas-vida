from datetime import date, timedelta

from django.contrib.auth.models import User
from django.test import TestCase

from Apps.coins.models import MonedaLedger
from Apps.poincs.models import VersionRegla
from Apps.users.models import Usuario
from services import monedas

GANAR = MonedaLedger.Tipo.OBJETIVO_CUMPLIDO
ENERO = date(2026, 1, 1)


class MonedasTests(TestCase):
    def setUp(self):
        user = User.objects.create_user(username="ana", password="clave-segura-1")
        self.usuario = Usuario.objects.create(
            user=user, usuario_id="ana-1", birth_date=date(1990, 1, 1)
        )
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]

    def _ganar(self, cantidad, fecha=ENERO):
        return monedas.acreditar(self.usuario, cantidad, GANAR, fecha=fecha)

    # --- ganar ---------------------------------------------------------------

    def test_acreditar_suma_y_sella_la_caducidad_a_90_dias(self):
        r = self._ganar(20)
        self.assertEqual(r.acreditadas, 20)
        self.assertEqual(r.saldo, 20)
        fila = MonedaLedger.objects.get(usuario=self.usuario)
        self.assertEqual(fila.fecha_expiracion, ENERO + timedelta(days=90))

    def test_no_se_acreditan_cantidades_cero_ni_negativas(self):
        for cantidad in (0, -5):
            with self.assertRaises(ValueError):
                self._ganar(cantidad)

    def test_el_tope_de_100_pierde_el_excedente(self):
        self._ganar(90)
        r = self._ganar(20)
        self.assertEqual(r.acreditadas, 10)
        self.assertEqual(r.perdidas_por_tope, 10)
        self.assertEqual(r.saldo, 100)

    def test_con_100_no_se_acredita_nada_y_no_se_escribe_fila(self):
        self._ganar(100)
        antes = MonedaLedger.objects.count()
        r = self._ganar(20)
        self.assertEqual(r.acreditadas, 0)
        self.assertEqual(r.perdidas_por_tope, 20)
        self.assertEqual(MonedaLedger.objects.count(), antes)

    def test_el_aviso_se_dispara_con_80_o_mas_no_solo_con_exactamente_80(self):
        self.assertFalse(self._ganar(79).aviso_80)
        self.assertTrue(self._ganar(1).aviso_80)       # llega a 80
        self.assertTrue(self._ganar(15).aviso_80)      # 95: sigue avisando

    def test_ganar_no_exige_poliza(self):
        # El servicio no mira pólizas: ganar es libre, gastar lo valida el canje.
        self.assertEqual(self._ganar(20).acreditadas, 20)

    # --- caducidad -----------------------------------------------------------

    def test_el_ultimo_dia_de_vigencia_todavia_se_pueden_usar(self):
        self._ganar(30)
        vence = ENERO + timedelta(days=90)
        self.assertEqual(monedas.saldo(self.usuario, vence), 30)

    def test_al_dia_siguiente_caducan_y_queda_constancia(self):
        self._ganar(30)
        despues = ENERO + timedelta(days=91)
        self.assertEqual(monedas.saldo(self.usuario, despues), 0)
        exp = MonedaLedger.objects.get(tipo=MonedaLedger.Tipo.EXPIRACION)
        self.assertEqual(exp.cantidad, -30)

    def test_expirar_dos_veces_no_escribe_dos_filas(self):
        self._ganar(30)
        despues = ENERO + timedelta(days=91)
        monedas.saldo(self.usuario, despues)
        monedas.saldo(self.usuario, despues)
        self.assertEqual(
            MonedaLedger.objects.filter(tipo=MonedaLedger.Tipo.EXPIRACION).count(), 1
        )

    def test_lo_caducado_libera_espacio_bajo_el_tope(self):
        self._ganar(100)
        despues = ENERO + timedelta(days=91)
        r = self._ganar(20, fecha=despues)
        self.assertEqual(r.acreditadas, 20)
        self.assertEqual(r.saldo, 20)

    # --- gastar --------------------------------------------------------------

    def test_gastar_descuenta_y_devuelve_el_saldo_resultante(self):
        self._ganar(50)
        self.assertEqual(monedas.gastar(self.usuario, 20, fecha=ENERO), 30)
        self.assertEqual(monedas.saldo(self.usuario, ENERO), 30)

    def test_gastar_sin_saldo_falla_y_no_escribe_nada(self):
        self._ganar(10)
        antes = MonedaLedger.objects.count()
        with self.assertRaises(monedas.SaldoInsuficiente) as cm:
            monedas.gastar(self.usuario, 20, fecha=ENERO)
        self.assertEqual(cm.exception.saldo, 10)
        self.assertEqual(MonedaLedger.objects.count(), antes)

    def test_no_se_pueden_gastar_monedas_ya_caducadas(self):
        self._ganar(30)
        despues = ENERO + timedelta(days=91)
        with self.assertRaises(monedas.SaldoInsuficiente):
            monedas.gastar(self.usuario, 10, fecha=despues)

    def test_se_gasta_primero_el_lote_que_vence_antes(self):
        a = ENERO
        b = ENERO + timedelta(days=30)
        self._ganar(30, fecha=a)
        self._ganar(30, fecha=b)
        monedas.gastar(self.usuario, 40, fecha=b)  # 30 del lote A + 10 del B

        # El lote A venció el 1 de abril; ya estaba consumido, no resta de nuevo.
        despues_de_a = a + timedelta(days=91)
        self.assertEqual(monedas.saldo(self.usuario, despues_de_a), 20)
        # Los 20 que quedaban del lote B vencen a los 90 días de ganados.
        despues_de_b = b + timedelta(days=91)
        self.assertEqual(monedas.saldo(self.usuario, despues_de_b), 0)

    def test_no_se_gastan_cantidades_cero_ni_negativas(self):
        self._ganar(10)
        for cantidad in (0, -1):
            with self.assertRaises(ValueError):
                monedas.gastar(self.usuario, cantidad, fecha=ENERO)

    # --- anulación por retroactivo denegado ----------------------------------

    def test_anular_ganadas_antes_del_corte_deja_solo_lo_posterior(self):
        self._ganar(20, fecha=date(2026, 3, 1))
        self._ganar(30, fecha=date(2026, 3, 20))
        hoy = date(2026, 3, 25)

        anuladas = monedas.anular_ganadas_antes_de(self.usuario, date(2026, 3, 10), hoy)

        self.assertEqual(anuladas, 20)
        self.assertEqual(monedas.saldo(self.usuario, hoy), 30)

    def test_anular_es_idempotente(self):
        self._ganar(20, fecha=date(2026, 3, 1))
        hoy = date(2026, 3, 25)
        corte = date(2026, 3, 10)
        monedas.anular_ganadas_antes_de(self.usuario, corte, hoy)
        self.assertEqual(monedas.anular_ganadas_antes_de(self.usuario, corte, hoy), 0)
        self.assertEqual(
            MonedaLedger.objects.filter(tipo=MonedaLedger.Tipo.AJUSTE_MANUAL).count(), 1
        )

    def test_anular_sin_nada_antes_del_corte_no_escribe_fila(self):
        self._ganar(20, fecha=date(2026, 3, 20))
        antes = MonedaLedger.objects.count()
        self.assertEqual(
            monedas.anular_ganadas_antes_de(self.usuario, date(2026, 3, 10), date(2026, 3, 25)),
            0,
        )
        self.assertEqual(MonedaLedger.objects.count(), antes)
