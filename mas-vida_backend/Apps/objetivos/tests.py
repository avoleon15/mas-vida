from datetime import date, datetime, timedelta
from io import StringIO
from zoneinfo import ZoneInfo

from django.contrib.auth.models import User
from django.core.management import CommandError, call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.activities.models import ResumenDiario
from Apps.coins.models import MonedaLedger
from Apps.objetivos.models import CumplimientoSemanal, MetaPasosPorEdad, ObjetivoSemanal
from Apps.policies.models import PolizaVinculada
from Apps.poincs.models import VersionRegla
from Apps.users.models import Usuario
from services import goals, monedas
from services.tiempo import fin_semana, inicio_semana, numero_season, rango_season

LUNES = date(2026, 9, 21)
DOMINGO = date(2026, 9, 27)
HOY = date(2026, 9, 29)  # el martes en que se cierra la semana anterior
EL_LUNES = date(2026, 9, 28)  # la semana ya terminó, pero sigue en su margen de gracia

# Pago de una semana COMPLETADA: cada componente paga lo suyo (5 + 5).
PAGO_SEMANA_COMPLETA = 2 * goals.MONEDAS_POR_COMPONENTE_INICIAL
PAGO_SOLO_PASOS = goals.MONEDAS_POR_COMPONENTE_INICIAL


def meta_fija(pasos=30_000):
    """Una sola meta de pasos para todas las edades.

    Las pruebas de la MECÁNICA del cierre (idempotencia, cron, retroactivo) no
    deben depender de la tabla provisional por edad, que va a cambiar con los
    datos del piloto. La tabla se prueba aparte (test_componentes.py).
    """
    MetaPasosPorEdad.objects.all().delete()
    MetaPasosPorEdad.objects.create(edad_desde=0, meta_pasos=pasos)


def crear_usuario(nombre, nacimiento=date(1990, 1, 1)):
    user = User.objects.create_user(username=nombre, password="clave-segura-1")
    return Usuario.objects.create(user=user, usuario_id=f"{nombre}-1", birth_date=nacimiento)


def dia(usuario, fecha, pasos, workouts=None):
    return ResumenDiario.objects.create(
        usuario=usuario, fecha=fecha, pasos_totales_dia=pasos,
        workouts_cantidad=workouts, puntos_dia=0,
    )


class TiempoTests(TestCase):
    def test_la_semana_va_de_lunes_a_domingo(self):
        for fecha in (date(2026, 9, 21), date(2026, 9, 24), date(2026, 9, 27)):
            self.assertEqual(inicio_semana(fecha), LUNES)
            self.assertEqual(fin_semana(fecha), DOMINGO)

    def test_el_lunes_ya_es_otra_semana(self):
        self.assertEqual(inicio_semana(date(2026, 9, 28)), date(2026, 9, 28))


class ObjetivoTests(TestCase):
    def test_la_primera_semana_usa_las_metas_iniciales(self):
        objetivo = goals.objetivo_de_la_semana(date(2026, 9, 24))
        self.assertEqual(objetivo.fecha_inicio, LUNES)
        self.assertEqual(objetivo.fecha_fin, DOMINGO)
        self.assertEqual(objetivo.meta_pasos, goals.META_PASOS_INICIAL)
        self.assertEqual(objetivo.meta_workouts, goals.META_WORKOUTS_INICIAL)

    def test_pedirlo_dos_veces_no_crea_dos_objetivos(self):
        goals.objetivo_de_la_semana(date(2026, 9, 24))
        goals.objetivo_de_la_semana(date(2026, 9, 22))
        self.assertEqual(ObjetivoSemanal.objects.count(), 1)

    def test_la_semana_nueva_copia_las_metas_editadas_de_la_anterior(self):
        actual = goals.objetivo_de_la_semana(LUNES)
        actual.meta_pasos = 45_000
        actual.meta_workouts = 2
        actual.save()
        siguiente = goals.objetivo_de_la_semana(HOY)
        self.assertEqual((siguiente.meta_pasos, siguiente.meta_workouts), (45_000, 2))

    def test_la_season_se_crea_una_sola_vez(self):
        a = goals.season_de(date(2026, 9, 1))
        b = goals.season_de(date(2026, 9, 27))  # último día de la season 3
        self.assertEqual(a.pk, b.pk)
        self.assertEqual(
            (a.numero, a.anio, a.fecha_inicio, a.fecha_fin),
            (3, 2026, date(2026, 6, 29), date(2026, 9, 27)),
        )

    def test_cumplido_exige_las_dos_metas(self):
        objetivo = goals.objetivo_de_la_semana(LUNES)
        solo_pasos = goals.Progreso(pasos=40_000, workouts=0, objetivo=objetivo)
        solo_workout = goals.Progreso(pasos=1_000, workouts=3, objetivo=objetivo)
        ambos = goals.Progreso(pasos=30_000, workouts=1, objetivo=objetivo)
        self.assertFalse(solo_pasos.cumplido)
        self.assertFalse(solo_workout.cumplido)
        self.assertTrue(ambos.cumplido)  # exactamente la meta cuenta


class CerrarSemanaTests(TestCase):
    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]
        self.ana = crear_usuario("ana")      # cumple
        self.beto = crear_usuario("beto")    # pasos sin workout
        self.carla = crear_usuario("carla")  # sin actividad
        meta_fija()
        dia(self.ana, LUNES, 20_000, workouts=1)
        dia(self.ana, date(2026, 9, 23), 11_000)
        dia(self.beto, LUNES, 35_000)

    def _cerrar(self, **kwargs):
        return goals.cerrar_semana(LUNES, HOY, **kwargs)

    def _cumplimiento(self, usuario):
        return CumplimientoSemanal.objects.get(
            usuario=usuario, objetivo_semanal__fecha_inicio=LUNES
        )

    def test_evalua_a_todos_y_cada_componente_paga_lo_suyo(self):
        resumen = self._cerrar()
        self.assertEqual(resumen["evaluados"], 3)
        self.assertEqual(resumen["cumplidos"], 1)            # semanas completadas
        self.assertEqual(resumen["pagos_pasos"], 2)          # ana y beto
        self.assertEqual(resumen["pagos_workouts"], 1)       # solo ana
        self.assertEqual(resumen["monedas_pagadas"], PAGO_SEMANA_COMPLETA + PAGO_SOLO_PASOS)

        self.assertTrue(self._cumplimiento(self.ana).cumplido)
        self.assertFalse(self._cumplimiento(self.beto).cumplido)   # no completó la semana
        self.assertTrue(self._cumplimiento(self.beto).cumplio_pasos)
        self.assertFalse(self._cumplimiento(self.carla).cumplido)
        self.assertEqual(monedas.saldo(self.ana, HOY), PAGO_SEMANA_COMPLETA)
        # Beto caminó pero no entrenó: antes no cobraba nada, ahora cobra los pasos.
        self.assertEqual(monedas.saldo(self.beto, HOY), PAGO_SOLO_PASOS)
        self.assertEqual(monedas.saldo(self.carla, HOY), 0)

    def test_guarda_lo_acumulado_de_cada_uno(self):
        self._cerrar()
        ana = self._cumplimiento(self.ana)
        self.assertEqual((ana.pasos_semanales, ana.workouts_acumulados), (31_000, 1))
        self.assertEqual(ana.evaluado_en, HOY)

    def test_las_monedas_se_pagan_con_o_sin_poliza(self):
        self.assertFalse(PolizaVinculada.objects.filter(usuario=self.ana).exists())
        self._cerrar()
        self.assertEqual(monedas.saldo(self.ana, HOY), PAGO_SEMANA_COMPLETA)

    def test_cada_componente_es_una_fila_de_objetivo_cumplido(self):
        self._cerrar()
        filas = list(MonedaLedger.objects.filter(usuario=self.ana).values_list("tipo", "cantidad"))
        self.assertEqual(
            filas,
            [(MonedaLedger.Tipo.OBJETIVO_CUMPLIDO, 5), (MonedaLedger.Tipo.OBJETIVO_CUMPLIDO, 5)],
        )

    def test_correr_dos_veces_no_paga_dos_veces(self):
        self._cerrar()
        segunda = self._cerrar()
        self.assertEqual(segunda["evaluados"], 0)
        self.assertEqual(monedas.saldo(self.ana, HOY), PAGO_SEMANA_COMPLETA)
        self.assertEqual(MonedaLedger.objects.filter(usuario=self.ana).count(), 2)

    def test_no_hay_tope_el_pago_se_suma_completo(self):
        monedas.acreditar(self.ana, 90, MonedaLedger.Tipo.AJUSTE_MANUAL, fecha=HOY)
        resumen = self._cerrar()
        self.assertEqual(resumen["monedas_pagadas"], PAGO_SEMANA_COMPLETA + PAGO_SOLO_PASOS)
        self.assertEqual(monedas.saldo(self.ana, HOY), 90 + PAGO_SEMANA_COMPLETA)

    def test_el_cierre_que_cae_en_la_season_nueva_reinicia_primero_y_paga_despues(self):
        # HOY es el lunes 28 sep: empieza la season 4. Las monedas de la season 3
        # (ganadas el 1 sep) se reinician y lo de la semana que cerró cuenta ya
        # en la season 4.
        monedas.acreditar(self.ana, 90, MonedaLedger.Tipo.AJUSTE_MANUAL, fecha=date(2026, 9, 1))
        self._cerrar()
        self.assertEqual(monedas.saldo(self.ana, HOY), PAGO_SEMANA_COMPLETA)
        tipos = list(
            MonedaLedger.objects.filter(usuario=self.ana).order_by("id").values_list("tipo", flat=True)
        )
        self.assertEqual(
            tipos,
            ["ajuste_manual", "expiracion", "objetivo_cumplido", "objetivo_cumplido"],
        )

    def test_una_semana_que_no_termino_no_se_evalua(self):
        with self.assertRaises(ValueError):
            goals.cerrar_semana(LUNES, DOMINGO)  # el domingo todavía corre

    def test_el_lunes_la_semana_sigue_en_su_margen_de_gracia(self):
        with self.assertRaises(ValueError):
            goals.cerrar_semana(LUNES, EL_LUNES)
        with self.assertRaises(ValueError):
            goals.cerrar_semana(LUNES, EL_LUNES, correccion=True)
        self.assertFalse(CumplimientoSemanal.objects.exists())

    def test_un_domingo_que_llega_el_lunes_todavia_cuenta(self):
        # Es la razón del margen: Carla no abrió la app el domingo; su domingo
        # llega el lunes, y la semana se cierra el martes.
        with self.assertRaises(ValueError):
            goals.cerrar_semana(LUNES, EL_LUNES)
        dia(self.carla, DOMINGO, 31_000, workouts=1)   # sincronizó el lunes
        self._cerrar()
        self.assertTrue(self._cumplimiento(self.carla).cumplido)
        self.assertEqual(monedas.saldo(self.carla, HOY), PAGO_SEMANA_COMPLETA)

    def test_el_martes_ya_se_puede_cerrar(self):
        self.assertEqual(goals.primer_dia_de_cierre(LUNES), HOY)

    def test_el_domingo_a_las_2359_cuenta_y_el_lunes_no(self):
        dia(self.carla, DOMINGO, 31_000, workouts=1)          # último día de la semana
        dia(self.beto, EL_LUNES, 5_000, workouts=1)           # ya es la semana nueva
        self._cerrar()
        self.assertTrue(self._cumplimiento(self.carla).cumplido)
        self.assertEqual(self._cumplimiento(self.beto).workouts_acumulados, 0)

    def test_deja_fijado_el_objetivo_de_la_semana_nueva(self):
        self._cerrar()
        # La semana nueva empieza el lunes, aunque la anterior se cierre el martes.
        self.assertTrue(ObjetivoSemanal.objects.filter(fecha_inicio=EL_LUNES).exists())

    def test_usa_las_metas_y_monedas_editadas_a_mano_en_el_admin(self):
        meta_fija(5_000)
        objetivo = goals.objetivo_de_la_semana(LUNES)
        objetivo.meta_workouts = 2
        objetivo.monedas_pasos = 8
        objetivo.save()
        self._cerrar()
        ana = self._cumplimiento(self.ana)
        self.assertTrue(ana.cumplio_pasos)
        self.assertFalse(ana.cumplio_workouts)       # tenía 1 workout y ahora piden 2
        self.assertFalse(ana.cumplido)
        self.assertEqual(ana.meta_pasos, 5_000)      # la meta usada queda guardada
        self.assertEqual(monedas.saldo(self.ana, HOY), 8)

    def test_los_workouts_salen_del_resumen_y_no_cuentan_doble(self):
        # Dos dispositivos registraron el mismo entrenamiento: el resumen ya
        # lo dejó en 1, y eso es lo que cuenta.
        self._cerrar()
        self.assertEqual(self._cumplimiento(self.ana).workouts_acumulados, 1)

    # --- corrida de corrección (lunes 12:00) ---------------------------------

    def test_la_correccion_actualiza_acumulados_pero_no_cambia_el_resultado(self):
        self._cerrar()
        dia(self.beto, date(2026, 9, 25), 1_000, workouts=1)  # llegó tarde: ya cumpliría
        dia(self.ana, date(2026, 9, 24), 5_000)

        resumen = self._cerrar(correccion=True)

        beto = self._cumplimiento(self.beto)
        self.assertEqual(beto.workouts_acumulados, 1)    # acumulado corregido
        self.assertFalse(beto.cumplido)                  # el resultado no se reabre
        self.assertFalse(beto.cumplio_workouts)
        # Conserva lo que cobró al cerrar (los pasos); el workout tardío no paga.
        self.assertEqual(monedas.saldo(self.beto, HOY), PAGO_SOLO_PASOS)
        self.assertEqual(self._cumplimiento(self.ana).pasos_semanales, 36_000)
        self.assertEqual(resumen["actualizados"], 3)

    def test_la_correccion_no_evalua_a_quien_no_fue_evaluado(self):
        resumen = self._cerrar(correccion=True)
        self.assertEqual(resumen["actualizados"], 0)
        self.assertFalse(CumplimientoSemanal.objects.exists())

    # --- retroactivo denegado ------------------------------------------------

    def _poliza_con_retroactivo_denegado(self, usuario, verificada_el):
        PolizaVinculada.objects.create(
            usuario=usuario, policy_number="P-1", insurer="X",
            policy_start_date=date(2026, 1, 1),
            birth_date_confirmada=date(1991, 1, 1),  # no coincide con 1990
            estado_verificacion="verificada",
            fecha_verificacion=datetime.combine(
                verificada_el, datetime.min.time(), tzinfo=ZoneInfo("America/Guatemala")
            ),
        )

    def test_una_semana_cerrada_antes_de_verificar_con_edad_distinta_no_paga(self):
        self._poliza_con_retroactivo_denegado(self.ana, date(2026, 9, 29))
        resumen = self._cerrar()
        # Los días anteriores a la verificación no cuentan para la meta (5 oct 2026): la semana
        # entera es anterior, así que queda en cero y no cumplida (antes quedaba "cumplida" sin pago).
        cumplimiento = self._cumplimiento(self.ana)
        self.assertFalse(cumplimiento.cumplido)
        self.assertEqual((cumplimiento.pasos_semanales, cumplimiento.workouts_acumulados), (0, 0))
        self.assertEqual(resumen["monedas_pagadas"], PAGO_SOLO_PASOS)  # solo beto: ana no cobra
        self.assertEqual(monedas.saldo(self.ana, HOY), 0)

    def test_si_la_edad_coincide_la_semana_anterior_a_verificar_si_paga(self):
        PolizaVinculada.objects.create(
            usuario=self.ana, policy_number="P-1", insurer="X",
            policy_start_date=date(2026, 1, 1),
            birth_date_confirmada=date(1990, 1, 1),  # coincide
            estado_verificacion="verificada",
            fecha_verificacion=timezone.now(),
        )
        self._cerrar()
        self.assertEqual(monedas.saldo(self.ana, HOY), PAGO_SEMANA_COMPLETA)

    def test_una_semana_posterior_a_la_verificacion_si_paga(self):
        self._poliza_con_retroactivo_denegado(self.ana, date(2026, 9, 20))
        self._cerrar()
        self.assertEqual(monedas.saldo(self.ana, HOY), PAGO_SEMANA_COMPLETA)

    # --- comando -------------------------------------------------------------

    def test_el_comando_cierra_la_semana_anterior_a_la_fecha_dada(self):
        salida = StringIO()
        call_command("cerrar_semana", "--fecha", "2026-09-29", stdout=salida)
        self.assertIn("2026-09-21", salida.getvalue())
        self.assertEqual(monedas.saldo(self.ana, HOY), PAGO_SEMANA_COMPLETA)

    def test_el_comando_se_puede_correr_dos_veces(self):
        call_command("cerrar_semana", "--fecha", "2026-09-29", stdout=StringIO())
        call_command("cerrar_semana", "--fecha", "2026-09-29", stdout=StringIO())
        self.assertEqual(monedas.saldo(self.ana, HOY), PAGO_SEMANA_COMPLETA)

    def test_el_comando_en_modo_correccion(self):
        call_command("cerrar_semana", "--fecha", "2026-09-29", stdout=StringIO())
        salida = StringIO()
        call_command("cerrar_semana", "--fecha", "2026-09-29", "--correccion", stdout=salida)
        self.assertIn("corrección", salida.getvalue())

    def test_el_comando_un_lunes_avisa_que_la_semana_sigue_en_gracia(self):
        with self.assertRaises(CommandError):
            call_command("cerrar_semana", "--fecha", "2026-09-28", stdout=StringIO())
        self.assertFalse(CumplimientoSemanal.objects.exists())

    def test_el_comando_rechaza_una_fecha_mal_escrita(self):
        with self.assertRaises(CommandError):
            call_command("cerrar_semana", "--fecha", "28-09-2026", stdout=StringIO())


# Las pruebas de objetivos/estado y objetivos/semanas están en test_componentes.py.


class PonerseAlDiaTests(TestCase):
    """Cerrar todas las semanas pendientes, no solo la anterior.

    Semanas usadas (lunes): 7 sep, 14 sep, 21 sep y 28 sep de 2026.
    """

    S0, S1, S2, S3 = date(2026, 9, 7), date(2026, 9, 14), date(2026, 9, 21), date(2026, 9, 28)
    LUNES_5_OCT = date(2026, 10, 5)  # la semana del 28 sep ya terminó, pero sigue en gracia
    MARTES_6_OCT = date(2026, 10, 6)  # ya se puede cerrar la del 28 sep

    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]
        self.ana = crear_usuario("ana")
        meta_fija()

    def _cumple(self, lunes):
        dia(self.ana, lunes, 31_000, workouts=1)

    # --- qué semanas faltan ---------------------------------------------------

    def test_sin_datos_ni_objetivos_no_hay_nada_pendiente(self):
        self.assertEqual(goals.semanas_pendientes(self.MARTES_6_OCT), [])

    def test_sin_nada_cerrado_empieza_por_la_primera_semana_con_datos(self):
        self._cumple(self.S1)
        self.assertEqual(
            goals.semanas_pendientes(self.MARTES_6_OCT), [self.S1, self.S2, self.S3]
        )

    def test_tras_cerrar_una_semana_solo_faltan_las_siguientes(self):
        self._cumple(self.S0)
        goals.cerrar_semana(self.S0, self.MARTES_6_OCT)
        self.assertEqual(
            goals.semanas_pendientes(self.MARTES_6_OCT), [self.S1, self.S2, self.S3]
        )

    def test_la_semana_en_curso_nunca_entra(self):
        self._cumple(self.S3)
        # Un jueves de la semana del 5 oct: la última terminada sigue siendo la del 28 sep.
        self.assertEqual(goals.semanas_pendientes(date(2026, 10, 8)), [self.S3])

    def test_el_domingo_la_semana_todavia_no_termino(self):
        self._cumple(self.S3)
        # Domingo 4 oct: la semana del 28 sep cierra hoy 23:59, aún no es "terminada".
        self.assertEqual(goals.semanas_pendientes(date(2026, 10, 4)), [])

    def test_el_lunes_la_semana_anterior_todavia_no_esta_pendiente(self):
        self._cumple(self.S3)
        # Lunes 5 oct: la del 28 sep terminó ayer, pero espera datos hasta el martes.
        self.assertEqual(goals.semanas_pendientes(self.LUNES_5_OCT), [])

    def test_el_martes_la_semana_anterior_ya_esta_pendiente(self):
        self._cumple(self.S3)
        self.assertEqual(goals.semanas_pendientes(self.MARTES_6_OCT), [self.S3])

    def test_ponerse_al_dia_un_lunes_no_cierra_la_semana_en_gracia(self):
        self._cumple(self.S2)
        self._cumple(self.S3)
        cerradas = goals.ponerse_al_dia(self.LUNES_5_OCT)
        self.assertEqual([l for l, _ in cerradas], [self.S2])

    def test_si_todo_esta_cerrado_no_queda_nada(self):
        self._cumple(self.S3)
        goals.cerrar_semana(self.S3, self.MARTES_6_OCT)
        self.assertEqual(goals.semanas_pendientes(self.MARTES_6_OCT), [])

    def test_una_semana_anterior_a_la_ultima_cerrada_no_se_reabre(self):
        self._cumple(self.S2)
        goals.cerrar_semana(self.S2, self.MARTES_6_OCT)
        dia(self.ana, self.S0, 31_000, workouts=1)  # dato viejo que aparece después
        self.assertEqual(goals.semanas_pendientes(self.MARTES_6_OCT), [self.S3])

    def test_el_tope_limita_cuantas_semanas_atrasadas_se_cierran(self):
        self._cumple(self.S0)
        martes_nov = date(2026, 11, 3)  # la última que se puede cerrar es la del 26 oct
        pendientes = goals.semanas_pendientes(martes_nov)
        self.assertEqual(len(pendientes), goals.MAX_SEMANAS_ATRASADAS)
        self.assertEqual(pendientes[-1], date(2026, 10, 26))
        self.assertEqual(pendientes[0], date(2026, 10, 5))

    # --- ponerse al día -------------------------------------------------------

    def test_cierra_todas_las_pendientes_en_orden_y_paga_cada_una(self):
        self._cumple(self.S1)
        self._cumple(self.S2)
        cerradas = goals.ponerse_al_dia(self.MARTES_6_OCT)

        self.assertEqual([l for l, _ in cerradas], [self.S1, self.S2, self.S3])
        self.assertEqual([r["cumplidos"] for _, r in cerradas], [1, 1, 0])
        self.assertEqual(monedas.saldo(self.ana, self.MARTES_6_OCT), 2 * PAGO_SEMANA_COMPLETA)

    def test_es_idempotente(self):
        self._cumple(self.S1)
        goals.ponerse_al_dia(self.MARTES_6_OCT)
        self.assertEqual(goals.ponerse_al_dia(self.MARTES_6_OCT), [])
        self.assertEqual(monedas.saldo(self.ana, self.MARTES_6_OCT), PAGO_SEMANA_COMPLETA)

    def test_crea_el_objetivo_de_las_semanas_que_no_tenian(self):
        self._cumple(self.S1)
        goals.ponerse_al_dia(self.MARTES_6_OCT)
        inicios = set(ObjetivoSemanal.objects.values_list("fecha_inicio", flat=True))
        self.assertTrue({self.S1, self.S2, self.S3, self.LUNES_5_OCT} <= inicios)

    def test_un_cron_que_fallo_un_martes_se_recupera_el_siguiente(self):
        self._cumple(self.S2)
        goals.cerrar_semana(self.S2, date(2026, 9, 29))   # el martes 29 sí corrió
        self._cumple(self.S3)                              # el martes 6 oct NO corrió
        # Corre el martes 13 oct: debe cerrar la del 28 sep que se quedó sin cerrar.
        cerradas = goals.ponerse_al_dia(date(2026, 10, 13))
        self.assertEqual([l for l, _ in cerradas], [self.S3, self.LUNES_5_OCT])
        self.assertEqual(monedas.saldo(self.ana, date(2026, 10, 13)), 2 * PAGO_SEMANA_COMPLETA)

    # --- comando --------------------------------------------------------------

    def test_el_comando_cierra_todas_con_ponerse_al_dia(self):
        self._cumple(self.S1)
        salida = StringIO()
        call_command("cerrar_semana", "--ponerse-al-dia", "--fecha", "2026-10-06", stdout=salida)
        texto = salida.getvalue()
        for lunes in ("2026-09-14", "2026-09-21", "2026-09-28"):
            self.assertIn(f"Semana {lunes}", texto)
        self.assertEqual(monedas.saldo(self.ana, self.MARTES_6_OCT), PAGO_SEMANA_COMPLETA)

    def test_el_comando_avisa_cuando_no_hay_nada_pendiente(self):
        salida = StringIO()
        call_command("cerrar_semana", "--ponerse-al-dia", "--fecha", "2026-10-06", stdout=salida)
        self.assertIn("No hay semanas pendientes", salida.getvalue())

    def test_ponerse_al_dia_no_se_combina_con_correccion(self):
        with self.assertRaises(CommandError):
            call_command(
                "cerrar_semana", "--ponerse-al-dia", "--correccion",
                "--fecha", "2026-10-06", stdout=StringIO(),
            )

    def test_el_comando_sin_la_bandera_sigue_cerrando_solo_la_anterior(self):
        self._cumple(self.S1)
        call_command("cerrar_semana", "--fecha", "2026-10-06", stdout=StringIO())
        self.assertEqual(
            CumplimientoSemanal.objects.values_list("objetivo_semanal__fecha_inicio", flat=True).distinct().count(),
            1,
        )
