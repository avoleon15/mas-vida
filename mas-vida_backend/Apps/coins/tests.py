from datetime import date, timedelta

from django.contrib.auth.models import User
from django.test import TestCase

from Apps.coins.models import MonedaLedger
from Apps.poincs.models import VersionRegla
from Apps.users.models import Usuario
from services import monedas

GANAR = MonedaLedger.Tipo.OBJETIVO_CUMPLIDO

# Seasons de 2026 (semanas ISO, lunes a domingo):
#   season 1: 29 dic 2025 a 29 mar 2026     season 2: 30 mar a 28 jun
#   season 3: 29 jun a 27 sep               season 4: 28 sep 2026 a 3 ene 2027
ENERO = date(2026, 1, 1)             # season 1
FIN_SEASON_1 = date(2026, 3, 29)     # domingo: último día que valen las monedas de la season 1
INICIO_SEASON_2 = date(2026, 3, 30)  # lunes: ya son de la season 2


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

    def test_acreditar_suma_y_sella_el_fin_de_la_season_como_vencimiento(self):
        r = self._ganar(20)
        self.assertEqual(r.acreditadas, 20)
        self.assertEqual(r.saldo, 20)
        fila = MonedaLedger.objects.get(usuario=self.usuario)
        self.assertEqual(fila.fecha_expiracion, FIN_SEASON_1)

    def test_no_se_acreditan_cantidades_cero_ni_negativas(self):
        for cantidad in (0, -5):
            with self.assertRaises(ValueError):
                self._ganar(cantidad)

    def test_ganar_no_exige_poliza(self):
        # El servicio no mira pólizas: ganar es libre, gastar lo valida el canje.
        self.assertEqual(self._ganar(20).acreditadas, 20)

    # --- sin tope ------------------------------------------------------------

    def test_no_hay_tope_de_acumulacion(self):
        self._ganar(100)
        r = self._ganar(50)
        self.assertEqual(r.acreditadas, 50)       # antes el excedente se perdía
        self.assertEqual(r.saldo, 150)
        self.assertEqual(monedas.saldo(self.usuario, ENERO), 150)

    def test_se_pueden_acumular_cifras_grandes(self):
        for _ in range(30):
            self._ganar(40)
        self.assertEqual(monedas.saldo(self.usuario, ENERO), 1200)

    def test_con_mas_de_100_cada_ganancia_deja_su_fila(self):
        self._ganar(100)
        self._ganar(20)
        self.assertEqual(MonedaLedger.objects.filter(usuario=self.usuario).count(), 2)

    # --- caducidad al cerrar la season --------------------------------------

    def test_el_ultimo_domingo_de_la_season_todavia_se_pueden_usar(self):
        self._ganar(30)
        self.assertEqual(monedas.saldo(self.usuario, FIN_SEASON_1), 30)

    def test_el_lunes_que_empieza_la_season_siguiente_el_saldo_vuelve_a_0(self):
        self._ganar(30)
        self.assertEqual(monedas.saldo(self.usuario, INICIO_SEASON_2), 0)
        exp = MonedaLedger.objects.get(tipo=MonedaLedger.Tipo.EXPIRACION)
        self.assertEqual(exp.cantidad, -30)

    def test_todo_lo_ganado_en_la_season_caduca_el_mismo_domingo(self):
        self._ganar(10, fecha=ENERO)                  # al principio de la season
        self._ganar(10, fecha=date(2026, 3, 28))      # el sábado antes del cierre
        self.assertEqual(monedas.saldo(self.usuario, FIN_SEASON_1), 20)
        self.assertEqual(monedas.saldo(self.usuario, INICIO_SEASON_2), 0)

    def test_lo_ganado_en_la_season_nueva_no_se_reinicia(self):
        self._ganar(30, fecha=ENERO)
        self._ganar(20, fecha=date(2026, 4, 1))       # ya es la season 2
        self.assertEqual(monedas.saldo(self.usuario, date(2026, 4, 1)), 20)

    def test_el_reinicio_ocurre_aunque_no_se_gane_nada_en_la_season_nueva(self):
        self._ganar(30)
        self.assertEqual(monedas.saldo(self.usuario, date(2026, 6, 1)), 0)

    def test_las_monedas_sin_poliza_se_reinician_igual(self):
        # Ninguna cuenta de estas pruebas tiene póliza: el reinicio es para todas.
        self._ganar(30)
        self.assertEqual(monedas.saldo(self.usuario, INICIO_SEASON_2), 0)

    def test_expirar_dos_veces_no_escribe_dos_filas(self):
        self._ganar(30)
        monedas.saldo(self.usuario, INICIO_SEASON_2)
        monedas.saldo(self.usuario, INICIO_SEASON_2)
        self.assertEqual(
            MonedaLedger.objects.filter(tipo=MonedaLedger.Tipo.EXPIRACION).count(), 1
        )

    def test_una_season_de_14_semanas_dura_hasta_su_domingo(self):
        # La season 4 de 2026 incluye la semana 53: cierra el 3 ene 2027.
        self._ganar(30, fecha=date(2026, 10, 2))
        self.assertEqual(monedas.saldo(self.usuario, date(2026, 12, 31)), 30)
        self.assertEqual(monedas.saldo(self.usuario, date(2027, 1, 3)), 30)
        self.assertEqual(monedas.saldo(self.usuario, date(2027, 1, 4)), 0)

    def test_las_filas_viejas_guardadas_con_90_dias_siguen_la_regla_nueva(self):
        # Una ganancia del 20 mar con el vencimiento de la regla vieja (90 días).
        MonedaLedger.objects.create(
            usuario=self.usuario, cantidad=20, tipo=GANAR,
            fecha=date(2026, 3, 20), fecha_expiracion=date(2026, 3, 20) + timedelta(days=90),
            version_regla=VersionRegla.objects.get(version=1),
        )
        self.assertEqual(monedas.saldo(self.usuario, FIN_SEASON_1), 20)
        # Con 90 días seguiría viva el 30 mar; con la regla nueva ya caducó.
        self.assertEqual(monedas.saldo(self.usuario, INICIO_SEASON_2), 0)

    # --- el orden del lunes en que cambia la season --------------------------

    def test_primero_se_reinicia_y_despues_se_paga_la_semana_que_cerro(self):
        self._ganar(50, fecha=date(2026, 3, 23))
        # Lunes 30 mar 00:00: se cierra la semana anterior y se paga con la fecha de hoy.
        r = self._ganar(10, fecha=INICIO_SEASON_2)

        self.assertEqual(r.saldo, 10)    # las 50 de la season 1 ya no cuentan
        filas = list(MonedaLedger.objects.filter(usuario=self.usuario).order_by("id"))
        self.assertEqual(
            [f.tipo for f in filas],
            [GANAR, MonedaLedger.Tipo.EXPIRACION, GANAR],  # reinicia y después paga
        )
        self.assertEqual([f.cantidad for f in filas], [50, -50, 10])

    def test_lo_pagado_ese_lunes_cuenta_en_la_season_nueva(self):
        self._ganar(10, fecha=INICIO_SEASON_2)
        # Vale hasta el cierre de la season 2 (domingo 28 jun) y no más.
        self.assertEqual(monedas.saldo(self.usuario, date(2026, 6, 28)), 10)
        self.assertEqual(monedas.saldo(self.usuario, date(2026, 6, 29)), 0)

    # --- aviso de fin de season ---------------------------------------------

    def test_fin_de_season(self):
        self.assertEqual(monedas.fin_de_season(ENERO), FIN_SEASON_1)
        self.assertEqual(monedas.fin_de_season(date(2026, 10, 2)), date(2027, 1, 3))

    def test_dias_para_el_fin_de_la_season(self):
        self.assertEqual(monedas.dias_para_fin_de_season(FIN_SEASON_1), 0)
        self.assertEqual(monedas.dias_para_fin_de_season(date(2026, 3, 22)), 7)
        self.assertEqual(monedas.dias_para_fin_de_season(INICIO_SEASON_2), 90)

    def test_el_aviso_empieza_7_dias_antes_del_cierre(self):
        self.assertFalse(monedas.aviso_fin_de_season(date(2026, 3, 21)))   # faltan 8
        self.assertTrue(monedas.aviso_fin_de_season(date(2026, 3, 22)))    # faltan 7
        self.assertTrue(monedas.aviso_fin_de_season(FIN_SEASON_1))         # último día
        self.assertFalse(monedas.aviso_fin_de_season(INICIO_SEASON_2))     # season nueva

    def test_el_aviso_en_la_season_de_14_semanas(self):
        self.assertFalse(monedas.aviso_fin_de_season(date(2026, 12, 26)))  # faltan 8
        self.assertTrue(monedas.aviso_fin_de_season(date(2026, 12, 27)))   # faltan 7

    # --- gastar --------------------------------------------------------------

    def test_gastar_descuenta_y_devuelve_el_saldo_resultante(self):
        self._ganar(50)
        self.assertEqual(monedas.gastar(self.usuario, 20, fecha=ENERO), 30)
        self.assertEqual(monedas.saldo(self.usuario, ENERO), 30)

    def test_se_puede_gastar_mas_de_100_ahora_que_no_hay_tope(self):
        for _ in range(3):
            self._ganar(60)
        self.assertEqual(monedas.gastar(self.usuario, 150, fecha=ENERO), 30)

    def test_gastar_sin_saldo_falla_y_no_escribe_nada(self):
        self._ganar(10)
        antes = MonedaLedger.objects.count()
        with self.assertRaises(monedas.SaldoInsuficiente) as cm:
            monedas.gastar(self.usuario, 20, fecha=ENERO)
        self.assertEqual(cm.exception.saldo, 10)
        self.assertEqual(MonedaLedger.objects.count(), antes)

    def test_no_se_pueden_gastar_monedas_de_una_season_que_ya_cerro(self):
        self._ganar(30)
        with self.assertRaises(monedas.SaldoInsuficiente):
            monedas.gastar(self.usuario, 10, fecha=INICIO_SEASON_2)

    def test_gastar_varias_ganancias_de_la_misma_season(self):
        self._ganar(30, fecha=ENERO)
        self._ganar(30, fecha=date(2026, 2, 1))
        monedas.gastar(self.usuario, 40, fecha=date(2026, 2, 1))   # 30 de una y 10 de otra
        self.assertEqual(monedas.saldo(self.usuario, date(2026, 2, 1)), 20)
        # Lo que quedó caduca igual con la season.
        self.assertEqual(monedas.saldo(self.usuario, INICIO_SEASON_2), 0)

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
