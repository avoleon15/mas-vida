"""Quien miente su edad pierde lo anterior a vincular; quien se equivoca, no (etapa 11, 5 oct 2026)."""
from datetime import date, datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient, APITestCase

from Apps.activities.models import ResumenDiario
from Apps.coins.models import MonedaLedger
from Apps.objetivos.models import CumplimientoSemanal
from Apps.poincs.models import Ledger, VersionRegla
from Apps.policies.models import PolizaVinculada, RegistroAseguradora
from Apps.users.models import Usuario
from Apps.users.pruebas import token_de
from services import goals, ligas, monedas, polizas

User = get_user_model()
GT = ZoneInfo("America/Guatemala")
VERIFICADA = PolizaVinculada.EstadoVerificacion.VERIFICADA
PENDIENTE = PolizaVinculada.EstadoVerificacion.PENDIENTE

REAL = date(1990, 5, 17)            # la de la aseguradora en casi todas las pruebas
HOY = date(2026, 10, 5)             # a esa fecha la persona real tiene 36 años


def version():
    return VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]


def crear_usuario(nombre, declarada):
    user = User.objects.create_user(f"{nombre}@correo.com", password="Clave-segura-2026")
    return Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=declarada)


def verificada(usuario, confirmada, cuando=None, numero=None):
    """Una póliza ya verificada ese día (por defecto, ahora), como la deja `vincular`."""
    return PolizaVinculada.objects.create(
        usuario=usuario, policy_number=numero or f"P-{usuario.pk}", insurer="Demo",
        estado_verificacion=VERIFICADA, birth_date_confirmada=confirmada,
        fecha_verificacion=cuando or timezone.now(),
    )


class EsMentiraTests(TestCase):
    """La regla pura. Con `fecha` = 5 oct 2026, la persona real (nacida el 17 may 1990) tiene 36 años."""

    def mentira(self, declarada, confirmada=REAL, fecha=HOY):
        return polizas.es_mentira(declarada, confirmada, fecha)

    def test_la_misma_fecha_no_es_mentira(self):
        self.assertFalse(self.mentira(REAL))

    # --- se puso MÁS JOVEN: nunca le conviene, se tolera hasta 2 años ----------

    def test_uno_o_dos_anios_mas_joven_es_un_error(self):
        self.assertFalse(self.mentira(date(1991, 5, 17)))
        self.assertFalse(self.mentira(date(1992, 5, 17)))        # justo 2 años

    def test_dos_anios_y_un_dia_mas_joven_ya_es_mentira(self):
        self.assertTrue(self.mentira(date(1992, 5, 18)))

    def test_el_mes_y_el_dia_equivocados_hacia_abajo_se_toleran(self):
        self.assertFalse(self.mentira(date(1990, 12, 30)))       # 7 meses más joven
        self.assertFalse(self.mentira(date(1990, 5, 18)))        # un día más joven

    # --- se puso MÁS VIEJA: le da ventaja aunque sea poco ----------------------

    def test_un_anio_mas_vieja_es_mentira_porque_le_baja_la_fcmax(self):
        self.assertTrue(self.mentira(date(1989, 5, 17)))

    def test_dos_anios_mas_vieja_es_mentira(self):
        self.assertTrue(self.mentira(date(1988, 5, 17)))

    def test_el_mes_y_el_dia_mas_viejos_cuentan_solo_si_cambian_los_anios_cumplidos(self):
        # Nacida el 2 ene 1990 en vez del 17 may: son 4 meses y medio más vieja.
        declarada = date(1990, 1, 2)
        self.assertFalse(self.mentira(declarada, fecha=date(2026, 10, 5)))     # las dos ya cumplieron 36
        self.assertTrue(self.mentira(declarada, fecha=date(2026, 3, 10)))      # una tiene 36 y la otra 35

    def test_cruzar_los_60_es_ventaja(self):
        real = date(1967, 6, 1)                                  # 59 años el 5 oct 2026
        self.assertTrue(self.mentira(date(1966, 1, 1), real))   # se dio 60: bono de +25
        self.assertFalse(self.mentira(date(1968, 6, 1), real))   # al revés, se hizo más joven

    def test_un_error_de_un_dia_que_cambia_la_edad_cumplida_es_ventaja(self):
        # Hoy cumple 30 la declarada y la real cumple mañana: 30 contra 29.
        self.assertTrue(self.mentira(date(1996, 10, 5), date(1996, 10, 6)))

    # --- bordes ---------------------------------------------------------------

    def test_el_29_de_febrero(self):
        real = date(1992, 2, 29)
        self.assertFalse(self.mentira(date(1994, 2, 28), real))  # 2 años más joven (el 29 cae en 28)
        self.assertTrue(self.mentira(date(1994, 3, 1), real))

    def test_una_fecha_futura_respecto_a_la_verificacion_no_rompe_la_regla(self):
        self.assertFalse(self.mentira(date(2026, 12, 1), date(2026, 11, 1), fecha=HOY))   # nadie nace después de hoy; solo no explota

    def test_la_ventaja_se_ve_en_las_tres_cosas_por_separado(self):
        # FCmáx más baja (una persona más vieja la tiene), bono de 60 y meta semanal.
        self.assertTrue(polizas.le_da_ventaja(date(1989, 5, 17), REAL, HOY))
        self.assertFalse(polizas.le_da_ventaja(date(1991, 5, 17), REAL, HOY))
        self.assertTrue(polizas.le_da_ventaja(date(1966, 1, 1), date(1967, 6, 1), HOY))


class CorteTests(TestCase):
    def setUp(self):
        version()

    def test_un_error_tolerado_no_tiene_corte(self):
        ana = crear_usuario("ana", declarada=date(1991, 5, 17))          # un año más joven
        verificada(ana, REAL)
        self.assertIsNone(polizas.fecha_corte_sin_retroactivo(ana))

    def test_una_mentira_tiene_corte_el_dia_de_la_verificacion(self):
        ana = crear_usuario("ana", declarada=date(1988, 5, 17))          # dos años más vieja
        verificada(ana, REAL, cuando=datetime(2026, 9, 24, 12, 0, tzinfo=GT))
        self.assertEqual(polizas.fecha_corte_sin_retroactivo(ana), date(2026, 9, 24))

    def test_sin_poliza_o_pendiente_no_hay_corte(self):
        crear_usuario("sola", declarada=date(1988, 5, 17))
        pendiente = crear_usuario("pend", declarada=date(1988, 5, 17))
        PolizaVinculada.objects.create(
            usuario=pendiente, policy_number="P-9", insurer="Demo", estado_verificacion=PENDIENTE,
            birth_date_confirmada=REAL,
        )
        for u in Usuario.objects.all():
            self.assertIsNone(polizas.fecha_corte_sin_retroactivo(u))

    def test_cortes_de_varios_devuelve_solo_a_los_que_mintieron(self):
        miente = crear_usuario("miente", declarada=date(1988, 5, 17))
        yerra = crear_usuario("yerra", declarada=date(1991, 5, 17))
        igual = crear_usuario("igual", declarada=REAL)
        sola = crear_usuario("sola", declarada=REAL)
        for u in (miente, yerra, igual):
            verificada(u, REAL, cuando=datetime(2026, 9, 24, 12, 0, tzinfo=GT))
        self.assertEqual(
            polizas.cortes_de_retroactivo([miente.pk, yerra.pk, igual.pk, sola.pk]),
            {miente.pk: date(2026, 9, 24)},
        )

    def test_el_dia_de_la_verificacion_es_el_de_guatemala_no_el_de_utc(self):
        ana = crear_usuario("ana", declarada=date(1988, 5, 17))
        # 24 sep 20:00 en Guatemala es el 25 en UTC.
        verificada(ana, REAL, cuando=datetime(2026, 9, 24, 20, 0, tzinfo=GT))
        self.assertEqual(polizas.fecha_corte_sin_retroactivo(ana), date(2026, 9, 24))


class VerificarTests(TestCase):
    def setUp(self):
        self.version = version()

    def historial(self, usuario):
        for dias in (3, 2, 1):
            Ledger.objects.create(
                usuario=usuario, fecha=timezone.localdate() - timedelta(days=dias), tipo=Ledger.TipoLedger.PASOS,
                puntos=50, version_regla=self.version,
            )
        monedas.acreditar(usuario, 5, MonedaLedger.Tipo.OBJETIVO_CUMPLIDO, fecha=timezone.localdate() - timedelta(days=2))

    def pendiente(self, usuario, confirmada):
        return PolizaVinculada.objects.create(
            usuario=usuario, policy_number=f"P-{usuario.pk}", insurer="Demo",
            estado_verificacion=PENDIENTE, birth_date_confirmada=confirmada,
        )

    def test_la_misma_fecha_se_aplica(self):
        ana = crear_usuario("ana", declarada=REAL)
        self.assertEqual(polizas.verificar(self.pendiente(ana, REAL)), "aplicado")

    def test_un_error_se_tolera_y_no_se_quita_nada(self):
        ana = crear_usuario("ana", declarada=date(1991, 5, 17))
        self.historial(ana)
        self.assertEqual(polizas.verificar(self.pendiente(ana, REAL)), "tolerado")
        self.assertFalse(Ledger.objects.filter(usuario=ana, tipo=Ledger.TipoLedger.RETROACTIVO_DENEGADO).exists())
        self.assertEqual(sum(Ledger.objects.filter(usuario=ana).values_list("puntos", flat=True)), 150)
        self.assertEqual(monedas.saldo(ana), 5)

    def test_una_mentira_anula_los_puntos_y_las_monedas_anteriores(self):
        ana = crear_usuario("ana", declarada=date(1988, 5, 17))
        self.historial(ana)
        self.assertEqual(polizas.verificar(self.pendiente(ana, REAL)), "denegado")
        self.assertEqual(Ledger.objects.filter(usuario=ana, tipo=Ledger.TipoLedger.RETROACTIVO_DENEGADO).count(), 3)
        self.assertEqual(sum(Ledger.objects.filter(usuario=ana).values_list("puntos", flat=True)), 0)
        self.assertEqual(monedas.saldo(ana), 0)

    def test_verificar_otra_vez_es_sin_cambios(self):
        ana = crear_usuario("ana", declarada=date(1991, 5, 17))
        poliza = self.pendiente(ana, REAL)
        polizas.verificar(poliza)
        self.assertEqual(polizas.verificar(poliza), "sin_cambios")


class VincularPorLaApiTests(APITestCase):
    def setUp(self):
        self.version = version()
        RegistroAseguradora.objects.create(
            numero_poliza="POL-X", aseguradora="Seguros Demo", nombre="Ana", apellido="Martínez",
            fecha_nacimiento=REAL, plan="Oro", prima_anual_gtq=Decimal("6000.00"),
            deducible_gtq=Decimal("1000"), coaseguro_pct=20, red="Red A",
            vigencia_inicio=date(2026, 1, 1), vigencia_fin=date(2027, 1, 1), estado="vigente",
        )

    def cuenta(self, nombre, declarada):
        usuario = crear_usuario(nombre, declarada)
        Ledger.objects.create(
            usuario=usuario, fecha=timezone.localdate() - timedelta(days=2), tipo=Ledger.TipoLedger.PASOS,
            puntos=50, version_regla=self.version,
        )
        cliente = APIClient()
        cliente.credentials(HTTP_AUTHORIZATION=f"Token {token_de(usuario.user)}")
        usuario.cliente = cliente
        return usuario

    def vincular(self, usuario):
        # El usuario escribe la fecha de la aseguradora; lo que se compara después es la del REGISTRO de la cuenta.
        r = usuario.cliente.post("/api/v1/polizas/vincular", {
            "policy_number": "POL-X", "insurer": "Seguros Demo", "birth_date": REAL.isoformat(),
        }, format="json")
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def puntos(self, usuario):
        return sum(Ledger.objects.filter(usuario=usuario).values_list("puntos", flat=True))

    def test_quien_se_equivoco_por_un_anio_conserva_su_historial(self):
        ana = self.cuenta("ana", declarada=date(1991, 5, 17))
        self.assertEqual(self.vincular(ana)["estado_verificacion"], "verificada")
        self.assertEqual(self.puntos(ana), 50)

    def test_quien_se_puso_un_anio_de_mas_pierde_su_historial(self):
        ana = self.cuenta("ana", declarada=date(1989, 5, 17))
        self.assertEqual(self.vincular(ana)["estado_verificacion"], "verificada")
        self.assertEqual(self.puntos(ana), 0)

    def test_quien_mintio_por_mucho_pierde_su_historial(self):
        ana = self.cuenta("ana", declarada=date(1960, 5, 17))
        self.vincular(ana)
        self.assertEqual(self.puntos(ana), 0)

    def test_la_misma_fecha_conserva_todo(self):
        ana = self.cuenta("ana", declarada=REAL)
        self.vincular(ana)
        self.assertEqual(self.puntos(ana), 50)


# --- lo anulado tampoco cuenta para la meta semanal ni para el desempate ----------

LUNES = date(2026, 9, 21)
CIERRE = date(2026, 9, 29)                       # el martes que se cierra la semana
JUEVES_12 = datetime(2026, 9, 24, 12, 0, tzinfo=GT)      # el día de la verificación


def resumen(usuario, dia, pasos, workouts=None):
    return ResumenDiario.objects.create(
        usuario=usuario, fecha=dia, pasos_totales_dia=pasos, workouts_cantidad=workouts, puntos_dia=0,
    )


class MetaSemanalTests(TestCase):
    """La semana que cruza la verificación: los días anteriores no cuentan para la meta."""

    def setUp(self):
        version()
        self.miente = crear_usuario("miente", declarada=date(1988, 5, 17))     # 2 años más vieja
        self.yerra = crear_usuario("yerra", declarada=date(1992, 5, 17))        # 2 años más joven
        for usuario in (self.miente, self.yerra):
            verificada(usuario, REAL, cuando=JUEVES_12)
            # Lunes a miércoles se camina mucho y se hace un workout; jueves a domingo, casi nada.
            for n in range(3):
                resumen(usuario, LUNES + timedelta(days=n), 20_000, workouts=1 if n == 0 else None)
            for n in range(3, 7):
                resumen(usuario, LUNES + timedelta(days=n), 1_000)

    def objetivo(self):
        return goals.objetivo_de_la_semana(LUNES)

    def test_el_avance_de_quien_mintio_empieza_el_dia_de_la_verificacion(self):
        avance = goals.progreso(self.miente, self.objetivo())
        self.assertEqual((avance.pasos, avance.workouts), (4_000, 0))          # jueves a domingo
        self.assertFalse(avance.cumplio_pasos or avance.cumplio_workouts)

    def test_el_avance_de_quien_solo_se_equivoco_cuenta_la_semana_entera(self):
        avance = goals.progreso(self.yerra, self.objetivo())
        self.assertEqual((avance.pasos, avance.workouts), (64_000, 1))
        self.assertTrue(avance.completada)

    def test_al_cerrar_la_semana_no_se_le_paga_a_quien_mintio_por_dias_anulados(self):
        goals.cerrar_semana(LUNES, CIERRE)
        miente = CumplimientoSemanal.objects.get(usuario=self.miente)
        self.assertEqual((miente.pasos_semanales, miente.workouts_acumulados), (4_000, 0))
        self.assertFalse(miente.cumplido)
        self.assertEqual(monedas.saldo(self.miente, CIERRE), 0)

    def test_al_cerrar_la_semana_a_quien_se_equivoco_si_se_le_paga(self):
        goals.cerrar_semana(LUNES, CIERRE)
        yerra = CumplimientoSemanal.objects.get(usuario=self.yerra)
        self.assertTrue(yerra.cumplido)
        self.assertEqual(monedas.saldo(self.yerra, CIERRE), 10)               # 5 de pasos + 5 de workouts

    def test_una_semana_posterior_a_la_verificacion_cuenta_completa(self):
        siguiente = LUNES + timedelta(days=7)
        for n in range(7):
            resumen(self.miente, siguiente + timedelta(days=n), 8_000, workouts=1 if n == 0 else None)
        avance = goals.progreso(self.miente, goals.objetivo_de_la_semana(siguiente))
        self.assertEqual((avance.pasos, avance.workouts), (56_000, 1))

    def test_una_semana_anterior_a_la_verificacion_no_cuenta_nada(self):
        anterior = LUNES - timedelta(days=7)
        for n in range(7):
            resumen(self.miente, anterior + timedelta(days=n), 20_000, workouts=1)
        avance = goals.progreso(self.miente, goals.objetivo_de_la_semana(anterior))
        self.assertEqual((avance.pasos, avance.workouts), (0, 0))

    def test_los_pasos_de_esos_dias_siguen_guardados_y_visibles(self):
        self.assertEqual(ResumenDiario.objects.get(usuario=self.miente, fecha=LUNES).pasos_totales_dia, 20_000)


class DesempateDeLigasTests(TestCase):
    """Con los mismos puntos, los pasos y workouts anteriores a la verificación no desempatan."""

    INICIO, HASTA = date(2026, 9, 1), date(2026, 9, 30)

    def setUp(self):
        self.version = version()
        self.miente = crear_usuario("miente", declarada=date(1988, 5, 17))
        self.yerra = crear_usuario("yerra", declarada=date(1992, 5, 17))
        self.honesta = crear_usuario("honesta", declarada=REAL)                # sin póliza
        for usuario in (self.miente, self.yerra, self.honesta):
            Ledger.objects.create(
                usuario=usuario, fecha=date(2026, 9, 20), tipo=Ledger.TipoLedger.PASOS, puntos=100, version_regla=self.version,
            )
        cuando = datetime(2026, 9, 15, 12, 0, tzinfo=GT)
        verificada(self.miente, REAL, cuando=cuando)
        verificada(self.yerra, REAL, cuando=cuando)
        for usuario in (self.miente, self.yerra):
            resumen(usuario, date(2026, 9, 10), 50_000, workouts=3)            # antes de la verificación
            resumen(usuario, date(2026, 9, 20), 1_000)                         # después
        resumen(self.honesta, date(2026, 9, 20), 10_000)

    def orden(self, hasta=None):
        pks = [self.miente.pk, self.yerra.pk, self.honesta.pk]
        return [f.usuario_pk for f in ligas.tabla(pks, self.INICIO, hasta or self.HASTA)]

    def test_los_pasos_anteriores_a_la_verificacion_de_quien_mintio_no_desempatan(self):
        # yerra (51.000 pasos, cuentan todos) > honesta (10.000) > miente (solo 1.000: los 50.000 se anularon)
        self.assertEqual(self.orden(), [self.yerra.pk, self.honesta.pk, self.miente.pk])

    def test_los_workouts_anteriores_tampoco_desempatan(self):
        filas = {f.usuario_pk: f for f in ligas.tabla([self.miente.pk, self.yerra.pk], self.INICIO, self.HASTA)}
        self.assertEqual((filas[self.miente.pk].pasos, filas[self.miente.pk].workouts), (1_000, 0))
        self.assertEqual((filas[self.yerra.pk].pasos, filas[self.yerra.pk].workouts), (51_000, 3))

    def test_un_mes_que_termina_antes_de_la_verificacion_no_cuenta_nada_para_quien_mintio(self):
        filas = ligas.tabla([self.miente.pk], date(2026, 9, 1), date(2026, 9, 14))
        self.assertEqual((filas[0].pasos, filas[0].workouts), (0, 0))

    def test_un_mes_posterior_a_la_verificacion_cuenta_completo(self):
        resumen(self.miente, date(2026, 10, 3), 7_000, workouts=1)
        filas = ligas.tabla([self.miente.pk], date(2026, 10, 1), date(2026, 10, 31))
        self.assertEqual((filas[0].pasos, filas[0].workouts), (7_000, 1))

    def test_quien_no_tiene_corte_queda_igual(self):
        filas = {f.usuario_pk: f for f in ligas.tabla([self.honesta.pk], self.INICIO, self.HASTA)}
        self.assertEqual(filas[self.honesta.pk].pasos, 10_000)

    def test_los_puntos_siguen_siendo_los_del_ledger(self):
        filas = {f.usuario_pk: f for f in ligas.tabla([self.miente.pk, self.yerra.pk], self.INICIO, self.HASTA)}
        self.assertEqual((filas[self.miente.pk].puntos, filas[self.yerra.pk].puntos), (100, 100))
