from datetime import date, datetime, timedelta, timezone as utc
from io import StringIO
from zoneinfo import ZoneInfo

from django.contrib.auth.models import User
from django.core.management import call_command
from django.test import SimpleTestCase, TestCase
from django.utils import timezone

from Apps.activities.models import ResumenDiario
from Apps.objetivos.models import CumplimientoSemanal, MetaPasosPorEdad
from Apps.poincs.models import VersionRegla
from Apps.users.models import Usuario
from services import monedas, programador
from services.programador import CIERRE, CORRECCION, correr, ejecutar, proxima_ejecucion
from services.tiempo import inicio_semana

GT = ZoneInfo("America/Guatemala")


def gt(anio, mes, dia, hora=0, minuto=0, segundo=0):
    return datetime(anio, mes, dia, hora, minuto, segundo, tzinfo=GT)


class ProximaEjecucionTests(SimpleTestCase):
    """2026-10-05 es lunes. Todas las horas son de Guatemala."""

    def test_el_domingo_por_la_noche_sigue_el_cierre_del_lunes(self):
        self.assertEqual(proxima_ejecucion(gt(2026, 10, 4, 23, 59)), (gt(2026, 10, 5, 0, 0), CIERRE))

    def test_justo_en_el_cierre_la_siguiente_es_la_correccion(self):
        # Estrictamente después: el cierre de las 00:00 no se repite a las 00:00.
        self.assertEqual(proxima_ejecucion(gt(2026, 10, 5, 0, 0)), (gt(2026, 10, 5, 12, 0), CORRECCION))

    def test_el_lunes_por_la_manana_sigue_la_correccion(self):
        self.assertEqual(proxima_ejecucion(gt(2026, 10, 5, 11, 59, 59)), (gt(2026, 10, 5, 12, 0), CORRECCION))

    def test_justo_en_la_correccion_la_siguiente_es_el_cierre_de_la_otra_semana(self):
        self.assertEqual(proxima_ejecucion(gt(2026, 10, 5, 12, 0)), (gt(2026, 10, 12, 0, 0), CIERRE))

    def test_a_mitad_de_semana_sigue_el_proximo_lunes(self):
        self.assertEqual(proxima_ejecucion(gt(2026, 10, 7, 15, 30)), (gt(2026, 10, 12, 0, 0), CIERRE))

    def test_cruza_el_fin_de_anio(self):
        self.assertEqual(proxima_ejecucion(gt(2026, 12, 28, 13, 0)), (gt(2027, 1, 4, 0, 0), CIERRE))

    def test_trabaja_en_hora_de_guatemala_aunque_llegue_en_utc(self):
        # Domingo 5:59 UTC = sábado 23:59 en Guatemala: el lunes en Guatemala
        # empieza a las 06:00 UTC.
        ahora_utc = datetime(2026, 10, 4, 5, 59, tzinfo=utc.utc)
        momento, tipo = proxima_ejecucion(ahora_utc)
        self.assertEqual(tipo, CIERRE)
        self.assertEqual(momento.astimezone(utc.utc), datetime(2026, 10, 5, 6, 0, tzinfo=utc.utc))

    def test_el_lunes_a_las_6_utc_ya_es_lunes_00_en_guatemala(self):
        ahora_utc = datetime(2026, 10, 5, 6, 0, tzinfo=utc.utc)
        momento, tipo = proxima_ejecucion(ahora_utc)
        self.assertEqual((momento, tipo), (gt(2026, 10, 5, 12, 0), CORRECCION))


class RelojFalso:
    """Un reloj que solo avanza cuando el programador 'duerme'."""

    def __init__(self, inicio):
        self.t = inicio
        self.dormidas = []

    def ahora(self):
        return self.t

    def dormir(self, segundos):
        self.dormidas.append(segundos)
        self.t += timedelta(seconds=segundos)


class BucleTests(SimpleTestCase):
    def _correr(self, inicio, corridas, ejecutar_fn=None, reloj=None):
        reloj = reloj or RelojFalso(inicio)
        hechas = []

        def registrar(tipo, momento):
            hechas.append((tipo, momento, reloj.ahora()))

        correr(
            reloj.ahora, reloj.dormir, ejecutar_fn or registrar,
            max_corridas=corridas,
        )
        return reloj, hechas

    def test_una_semana_completa_dispara_cierre_correccion_y_cierre(self):
        _, hechas = self._correr(gt(2026, 10, 4, 23, 0), corridas=3)
        self.assertEqual(
            [(t, m) for t, m, _ in hechas],
            [
                (CIERRE, gt(2026, 10, 5, 0, 0)),
                (CORRECCION, gt(2026, 10, 5, 12, 0)),
                (CIERRE, gt(2026, 10, 12, 0, 0)),
            ],
        )

    def test_nunca_corre_antes_de_su_hora(self):
        _, hechas = self._correr(gt(2026, 10, 4, 23, 0), corridas=3)
        for _, programado, reloj in hechas:
            self.assertGreaterEqual(reloj, programado)

    def test_despierta_en_pasos_cortos(self):
        reloj, _ = self._correr(gt(2026, 10, 7, 9, 0), corridas=1)
        self.assertTrue(reloj.dormidas)
        self.assertLessEqual(max(reloj.dormidas), programador.PASO_MAXIMO_SEGUNDOS)

    def test_un_error_se_reintenta_y_despues_sigue(self):
        intentos = []

        def falla_una_vez(tipo, momento):
            intentos.append(tipo)
            if len(intentos) == 1:
                raise RuntimeError("base de datos caída")

        with self.assertLogs("services.programador", level="ERROR"):
            reloj, _ = self._correr(
                gt(2026, 10, 4, 23, 59), corridas=1, ejecutar_fn=falla_una_vez
            )
        self.assertEqual(intentos, [CIERRE, CIERRE])
        self.assertIn(programador.REINTENTO_SEGUNDOS, reloj.dormidas)

    def test_si_siempre_falla_se_rinde_pero_el_programador_sigue_vivo(self):
        intentos = []

        def siempre_falla(tipo, momento):
            intentos.append((tipo, momento))
            raise RuntimeError("no hay base de datos")

        # Dos corridas: la primera agota los reintentos y la segunda igual se intenta.
        with self.assertLogs("services.programador", level="ERROR"):
            self._correr(gt(2026, 10, 4, 23, 59), corridas=2, ejecutar_fn=siempre_falla)
        self.assertEqual(len(intentos), 2 * programador.MAX_INTENTOS)

    def test_antes_de_ejecutar_se_llama_en_cada_intento(self):
        llamadas = []
        reloj = RelojFalso(gt(2026, 10, 4, 23, 59))
        correr(
            reloj.ahora, reloj.dormir, lambda t, m: None,
            antes_de_ejecutar=lambda: llamadas.append(1), max_corridas=2,
        )
        self.assertEqual(len(llamadas), 2)

    def test_si_el_servidor_se_suspende_no_repite_ni_se_salta_corridas(self):
        reloj = RelojFalso(gt(2026, 10, 4, 23, 0))
        hechas = []

        def ejecutar_y_saltar(tipo, momento):
            hechas.append(tipo)
            if len(hechas) == 1:
                reloj.t = gt(2026, 10, 13, 8, 0)  # el servidor estuvo apagado una semana

        correr(reloj.ahora, reloj.dormir, ejecutar_y_saltar, max_corridas=3)
        # Tras la primera, parte de la hora programada (no de "ahora"): la
        # corrección atrasada y luego el cierre atrasado se disparan, en orden.
        self.assertEqual(hechas, [CIERRE, CORRECCION, CIERRE])


# 5 + 5: una semana completada (ver services/goals.py).
PAGO_SEMANA_COMPLETA = 10


def meta_fija(pasos=30_000):
    """Una sola meta de pasos para todas las edades: aquí se prueba el programador."""
    MetaPasosPorEdad.objects.all().delete()
    MetaPasosPorEdad.objects.create(edad_desde=0, meta_pasos=pasos)


def crear_usuario(nombre):
    user = User.objects.create_user(username=nombre, password="clave-segura-1")
    return Usuario.objects.create(user=user, usuario_id=f"{nombre}-1", birth_date=date(1990, 1, 1))


class EjecutarTests(TestCase):
    LUNES = date(2026, 9, 28)   # semana a evaluar
    SIGUIENTE = date(2026, 10, 5)

    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]
        self.ana = crear_usuario("ana")
        meta_fija()
        ResumenDiario.objects.create(
            usuario=self.ana, fecha=self.LUNES, pasos_totales_dia=31_000,
            workouts_cantidad=1, puntos_dia=0,
        )

    def test_el_cierre_paga_a_quien_cumplio(self):
        ejecutar(CIERRE, gt(2026, 10, 5, 0, 0))
        self.assertEqual(monedas.saldo(self.ana, self.SIGUIENTE), PAGO_SEMANA_COMPLETA)
        self.assertTrue(CumplimientoSemanal.objects.get(usuario=self.ana).cumplido)

    def test_el_cierre_pone_al_dia_las_semanas_que_se_quedaron_sin_cerrar(self):
        ejecutar(CIERRE, gt(2026, 10, 12, 0, 0))  # nadie corrió el 5 de octubre
        self.assertEqual(monedas.saldo(self.ana, date(2026, 10, 12)), PAGO_SEMANA_COMPLETA)

    def test_el_cierre_dos_veces_no_paga_dos_veces(self):
        ejecutar(CIERRE, gt(2026, 10, 5, 0, 0))
        ejecutar(CIERRE, gt(2026, 10, 5, 0, 0))
        self.assertEqual(monedas.saldo(self.ana, self.SIGUIENTE), PAGO_SEMANA_COMPLETA)

    def test_la_correccion_actualiza_acumulados_sin_pagar_ni_reabrir(self):
        beto = crear_usuario("beto")
        ejecutar(CIERRE, gt(2026, 10, 5, 0, 0))
        ResumenDiario.objects.create(
            usuario=beto, fecha=date(2026, 9, 30), pasos_totales_dia=40_000,
            workouts_cantidad=2, puntos_dia=0,
        )  # llegó tarde, ya cumpliría

        ejecutar(CORRECCION, gt(2026, 10, 5, 12, 0))

        cumplimiento = CumplimientoSemanal.objects.get(usuario=beto)
        self.assertEqual(cumplimiento.pasos_semanales, 40_000)  # acumulado corregido
        self.assertFalse(cumplimiento.cumplido)                 # el resultado no se reabre
        self.assertEqual(monedas.saldo(beto, self.SIGUIENTE), 0)

    def test_una_corrida_desconocida_falla(self):
        with self.assertRaises(ValueError):
            ejecutar("otra", gt(2026, 10, 5))


class ComandoProgramadorTests(TestCase):
    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]
        self.ana = crear_usuario("ana")
        meta_fija()

    def test_una_vez_se_pone_al_dia_y_dice_cuando_es_la_proxima_corrida(self):
        hoy = timezone.localdate()
        semana_pasada = inicio_semana(hoy) - timedelta(days=14)
        ResumenDiario.objects.create(
            usuario=self.ana, fecha=semana_pasada, pasos_totales_dia=31_000,
            workouts_cantidad=1, puntos_dia=0,
        )

        salida = StringIO()
        call_command("programador", "--una-vez", stdout=salida)

        texto = salida.getvalue()
        self.assertIn(f"semana {semana_pasada}", texto)
        self.assertIn("Próxima corrida:", texto)
        self.assertIn("hora de Guatemala", texto)
        self.assertEqual(monedas.saldo(self.ana, hoy), PAGO_SEMANA_COMPLETA)

    def test_una_vez_sin_nada_pendiente_lo_dice(self):
        salida = StringIO()
        call_command("programador", "--una-vez", stdout=salida)
        self.assertIn("no hay semanas pendientes", salida.getvalue())
