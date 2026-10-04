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
from Apps.objetivos.models import CumplimientoSemanal, ObjetivoSemanal
from Apps.policies.models import PolizaVinculada
from Apps.poincs.models import VersionRegla
from Apps.users.models import Usuario
from services import goals, monedas
from services.tiempo import fin_semana, inicio_semana, numero_season, rango_season

LUNES = date(2026, 9, 21)
DOMINGO = date(2026, 9, 27)
HOY = date(2026, 9, 29)  # el martes en que se cierra la semana anterior
EL_LUNES = date(2026, 9, 28)  # la semana ya terminó, pero sigue en su margen de gracia


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
        dia(self.ana, LUNES, 20_000, workouts=1)
        dia(self.ana, date(2026, 9, 23), 11_000)
        dia(self.beto, LUNES, 35_000)

    def _cerrar(self, **kwargs):
        return goals.cerrar_semana(LUNES, HOY, **kwargs)

    def _cumplimiento(self, usuario):
        return CumplimientoSemanal.objects.get(
            usuario=usuario, objetivo_semanal__fecha_inicio=LUNES
        )

    def test_evalua_a_todos_y_paga_solo_a_quien_cumplio(self):
        resumen = self._cerrar()
        self.assertEqual(resumen["evaluados"], 3)
        self.assertEqual(resumen["cumplidos"], 1)
        self.assertEqual(resumen["monedas_pagadas"], 20)

        self.assertTrue(self._cumplimiento(self.ana).cumplido)
        self.assertFalse(self._cumplimiento(self.beto).cumplido)
        self.assertFalse(self._cumplimiento(self.carla).cumplido)
        self.assertEqual(monedas.saldo(self.ana, HOY), 20)
        self.assertEqual(monedas.saldo(self.beto, HOY), 0)

    def test_guarda_lo_acumulado_de_cada_uno(self):
        self._cerrar()
        ana = self._cumplimiento(self.ana)
        self.assertEqual((ana.pasos_semanales, ana.workouts_acumulados), (31_000, 1))
        self.assertEqual(ana.evaluado_en, HOY)

    def test_las_monedas_se_pagan_con_o_sin_poliza(self):
        self.assertFalse(PolizaVinculada.objects.filter(usuario=self.ana).exists())
        self._cerrar()
        self.assertEqual(monedas.saldo(self.ana, HOY), goals.MONEDAS_POR_OBJETIVO)

    def test_las_monedas_se_pagan_como_objetivo_cumplido(self):
        self._cerrar()
        fila = MonedaLedger.objects.get(usuario=self.ana)
        self.assertEqual(fila.tipo, MonedaLedger.Tipo.OBJETIVO_CUMPLIDO)
        self.assertEqual(fila.cantidad, 20)

    def test_correr_dos_veces_no_paga_dos_veces(self):
        self._cerrar()
        segunda = self._cerrar()
        self.assertEqual(segunda["evaluados"], 0)
        self.assertEqual(monedas.saldo(self.ana, HOY), 20)
        self.assertEqual(MonedaLedger.objects.filter(usuario=self.ana).count(), 1)

    def test_no_hay_tope_el_pago_se_suma_completo(self):
        monedas.acreditar(self.ana, 90, MonedaLedger.Tipo.AJUSTE_MANUAL, fecha=HOY)
        resumen = self._cerrar()
        self.assertEqual(resumen["monedas_pagadas"], goals.MONEDAS_POR_OBJETIVO)
        self.assertEqual(monedas.saldo(self.ana, HOY), 90 + goals.MONEDAS_POR_OBJETIVO)

    def test_el_cierre_que_cae_en_la_season_nueva_reinicia_primero_y_paga_despues(self):
        # HOY es el lunes 28 sep: empieza la season 4. Las monedas de la season 3
        # (ganadas el 1 sep) se reinician y lo de la semana que cerró cuenta ya
        # en la season 4.
        monedas.acreditar(self.ana, 90, MonedaLedger.Tipo.AJUSTE_MANUAL, fecha=date(2026, 9, 1))
        self._cerrar()
        self.assertEqual(monedas.saldo(self.ana, HOY), goals.MONEDAS_POR_OBJETIVO)
        tipos = list(
            MonedaLedger.objects.filter(usuario=self.ana).order_by("id").values_list("tipo", flat=True)
        )
        self.assertEqual(
            tipos,
            ["ajuste_manual", "expiracion", "objetivo_cumplido"],
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
        self.assertEqual(monedas.saldo(self.carla, HOY), 20)

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

    def test_usa_las_metas_editadas_a_mano_en_el_admin(self):
        objetivo = goals.objetivo_de_la_semana(LUNES)
        objetivo.meta_pasos = 5_000
        objetivo.save()
        self._cerrar()
        self.assertTrue(self._cumplimiento(self.beto).cumplido is False)  # sin workout
        self.assertTrue(self._cumplimiento(self.ana).cumplido)

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
        self.assertEqual(monedas.saldo(self.beto, HOY), 0)
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
        self.assertTrue(self._cumplimiento(self.ana).cumplido)   # se registra
        self.assertEqual(resumen["monedas_pagadas"], 0)          # pero no paga
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
        self.assertEqual(monedas.saldo(self.ana, HOY), 20)

    def test_una_semana_posterior_a_la_verificacion_si_paga(self):
        self._poliza_con_retroactivo_denegado(self.ana, date(2026, 9, 20))
        self._cerrar()
        self.assertEqual(monedas.saldo(self.ana, HOY), 20)

    # --- comando -------------------------------------------------------------

    def test_el_comando_cierra_la_semana_anterior_a_la_fecha_dada(self):
        salida = StringIO()
        call_command("cerrar_semana", "--fecha", "2026-09-29", stdout=salida)
        self.assertIn("2026-09-21", salida.getvalue())
        self.assertEqual(monedas.saldo(self.ana, HOY), 20)

    def test_el_comando_se_puede_correr_dos_veces(self):
        call_command("cerrar_semana", "--fecha", "2026-09-29", stdout=StringIO())
        call_command("cerrar_semana", "--fecha", "2026-09-29", stdout=StringIO())
        self.assertEqual(monedas.saldo(self.ana, HOY), 20)

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


class RetosEstadoTests(APITestCase):
    url = "/api/v1/retos/estado"

    def setUp(self):
        self.hoy = timezone.localdate()
        self.usuario = crear_usuario("ana")
        token = Token.objects.get(user=self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_sin_token_da_401(self):
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_la_forma_sigue_el_contrato(self):
        r = self.client.get(self.url)
        self.assertEqual(r.status_code, 200)
        datos = r.json()
        self.assertEqual(
            datos["objetivo"],
            {
                "meta_pasos": goals.META_PASOS_INICIAL,
                "meta_workouts": goals.META_WORKOUTS_INICIAL,
                "monedas_al_cumplir": goals.MONEDAS_POR_OBJETIVO,
                "fecha_inicio": inicio_semana(self.hoy).isoformat(),
                "fecha_fin": fin_semana(self.hoy).isoformat(),
            },
        )
        self.assertEqual(
            datos["progreso"],
            {"pasos_acumulados": 0, "workouts_acumulados": 0, "cumplido": False},
        )
        self.assertEqual(
            datos["season"],
            {
                "numero": numero_season(self.hoy),
                "fecha_cierre": rango_season(self.hoy)[1].isoformat(),
            },
        )
        self.assertEqual(datos["historial_seasons"], [])

    def test_el_progreso_suma_los_dias_de_la_semana_en_curso(self):
        lunes = inicio_semana(self.hoy)
        dia(self.usuario, lunes, 12_400)
        dia(self.usuario, lunes + timedelta(days=1), 5_000, workouts=1)
        progreso = self.client.get(self.url).json()["progreso"]
        self.assertEqual(progreso["pasos_acumulados"], 17_400)
        self.assertEqual(progreso["workouts_acumulados"], 1)
        self.assertFalse(progreso["cumplido"])

    def test_cumplido_cuando_se_alcanzan_las_dos_metas(self):
        dia(self.usuario, inicio_semana(self.hoy), 30_000, workouts=1)
        self.assertTrue(self.client.get(self.url).json()["progreso"]["cumplido"])

    def test_no_cuenta_los_dias_de_otras_semanas(self):
        dia(self.usuario, inicio_semana(self.hoy) - timedelta(days=1), 50_000, workouts=3)
        progreso = self.client.get(self.url).json()["progreso"]
        self.assertEqual((progreso["pasos_acumulados"], progreso["workouts_acumulados"]), (0, 0))

    def test_el_progreso_es_solo_del_usuario_que_pregunta(self):
        otro = crear_usuario("beto")
        dia(otro, inicio_semana(self.hoy), 40_000, workouts=2)
        progreso = self.client.get(self.url).json()["progreso"]
        self.assertEqual(progreso["pasos_acumulados"], 0)

    def test_el_objetivo_es_igual_para_todos(self):
        otro = crear_usuario("beto")
        token = Token.objects.get(user=otro.user)
        mio = self.client.get(self.url).json()["objetivo"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        del_otro = self.client.get(self.url).json()["objetivo"]
        self.assertEqual(mio, del_otro)

    def test_refleja_las_metas_editadas_en_el_admin(self):
        objetivo = goals.objetivo_de_la_semana(self.hoy)
        objetivo.meta_pasos = 12_345
        objetivo.save()
        self.assertEqual(self.client.get(self.url).json()["objetivo"]["meta_pasos"], 12_345)

    def test_pedirlo_varias_veces_no_crea_objetivos_de_mas(self):
        for _ in range(3):
            self.client.get(self.url)
        self.assertEqual(ObjetivoSemanal.objects.count(), 1)


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
        self.assertEqual(monedas.saldo(self.ana, self.MARTES_6_OCT), 40)

    def test_es_idempotente(self):
        self._cumple(self.S1)
        goals.ponerse_al_dia(self.MARTES_6_OCT)
        self.assertEqual(goals.ponerse_al_dia(self.MARTES_6_OCT), [])
        self.assertEqual(monedas.saldo(self.ana, self.MARTES_6_OCT), 20)

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
        self.assertEqual(monedas.saldo(self.ana, date(2026, 10, 13)), 40)

    # --- comando --------------------------------------------------------------

    def test_el_comando_cierra_todas_con_ponerse_al_dia(self):
        self._cumple(self.S1)
        salida = StringIO()
        call_command("cerrar_semana", "--ponerse-al-dia", "--fecha", "2026-10-06", stdout=salida)
        texto = salida.getvalue()
        for lunes in ("2026-09-14", "2026-09-21", "2026-09-28"):
            self.assertIn(f"Semana {lunes}", texto)
        self.assertEqual(monedas.saldo(self.ana, self.MARTES_6_OCT), 20)

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
