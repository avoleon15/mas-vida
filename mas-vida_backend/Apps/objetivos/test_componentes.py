"""Objetivo semanal por componente (reunión del 2 oct 2026).

- La meta de pasos sale del rango de edad (MetaPasosPorEdad), medida el lunes.
- Cada componente paga lo suyo; la semana queda completada solo con los dos.
- objetivos/estado y objetivos/semanas (vista de la season).
"""
import importlib
from datetime import date, timedelta
from unittest import mock

from django.apps import apps as registro_apps
from django.test import TestCase
from rest_framework.test import APITestCase

from Apps.coins.models import MonedaLedger
from Apps.objetivos.models import CumplimientoSemanal, MetaPasosPorEdad
from Apps.objetivos.tests import crear_usuario, dia
from Apps.policies.models import PolizaVinculada
from Apps.poincs.models import VersionRegla
from Apps.users.pruebas import token_de
from services import goals, monedas

LUNES = date(2026, 9, 21)
HOY = date(2026, 9, 29)  # el martes en que se cierra la semana del 21 (el lunes 28 es margen de gracia)

# Season 4 de 2026: arranca el lunes 28 de sep y, como 2026 tiene semana ISO 53,
# trae 14 semanas (cierra el domingo 3 de enero de 2027).
MIERCOLES_SEMANA_2 = date(2026, 10, 7)


class MetaPorEdadTests(TestCase):
    """La tabla provisional que carga la migración 0002."""

    def test_cada_rango_de_edad_tiene_su_meta(self):
        casos = {
            18: 49_000, 29: 49_000, 30: 49_000, 39: 49_000,
            40: 45_000, 49: 45_000, 50: 42_000, 59: 42_000,
            60: 35_000, 69: 35_000, 70: 31_000, 95: 31_000,
        }
        for edad, meta in casos.items():
            with self.subTest(edad=edad):
                self.assertEqual(goals.meta_pasos_para_edad(edad), meta)

    def test_un_menor_de_18_usa_la_primera_fila(self):
        self.assertEqual(goals.meta_pasos_para_edad(16), 49_000)

    def test_sin_tabla_usa_el_respaldo_del_objetivo(self):
        MetaPasosPorEdad.objects.all().delete()
        self.assertEqual(goals.meta_pasos_para_edad(40, respaldo=30_000), 30_000)
        with self.assertRaises(ValueError):
            goals.meta_pasos_para_edad(40)

    def test_la_edad_se_mide_el_lunes_de_la_semana(self):
        # Cumple 40 el miércoles: esa semana todavía le toca la meta de 39.
        usuario = crear_usuario("ana", nacimiento=date(1986, 9, 23))
        objetivo = goals.objetivo_de_la_semana(LUNES)
        self.assertEqual(goals.meta_pasos_de(usuario, objetivo), 49_000)
        siguiente = goals.objetivo_de_la_semana(HOY)
        self.assertEqual(goals.meta_pasos_de(usuario, siguiente), 45_000)

    def test_manda_la_fecha_confirmada_por_la_aseguradora(self):
        usuario = crear_usuario("ana", nacimiento=date(1990, 1, 1))  # 36 años
        PolizaVinculada.objects.create(
            usuario=usuario, policy_number="P-1", insurer="Demo",
            birth_date_confirmada=date(1960, 1, 1),                # 66 años
            estado_verificacion=PolizaVinculada.EstadoVerificacion.VERIFICADA,
        )
        objetivo = goals.objetivo_de_la_semana(LUNES)
        self.assertEqual(goals.meta_pasos_de(usuario, objetivo), 35_000)


class PagoPorComponenteTests(TestCase):
    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        self.joven = crear_usuario("joven", nacimiento=date(2000, 1, 1))     # 26 → 49.000
        self.mayor = crear_usuario("mayor", nacimiento=date(1955, 1, 1))     # 71 → 31.000

    def _cumplimiento(self, usuario):
        return CumplimientoSemanal.objects.get(usuario=usuario)

    def test_los_mismos_pasos_cumplen_para_uno_y_no_para_otro(self):
        dia(self.joven, LUNES, 35_000)
        dia(self.mayor, LUNES, 35_000)
        goals.cerrar_semana(LUNES, HOY)
        self.assertFalse(self._cumplimiento(self.joven).cumplio_pasos)
        self.assertEqual(self._cumplimiento(self.joven).meta_pasos, 49_000)
        self.assertTrue(self._cumplimiento(self.mayor).cumplio_pasos)
        self.assertEqual(self._cumplimiento(self.mayor).meta_pasos, 31_000)
        self.assertEqual(monedas.saldo(self.joven, HOY), 0)
        self.assertEqual(monedas.saldo(self.mayor, HOY), 5)

    def test_solo_el_workout_paga_lo_suyo(self):
        dia(self.joven, LUNES, 2_000, workouts=1)
        goals.cerrar_semana(LUNES, HOY)
        c = self._cumplimiento(self.joven)
        self.assertEqual((c.cumplio_pasos, c.cumplio_workouts, c.cumplido), (False, True, False))
        self.assertEqual(monedas.saldo(self.joven, HOY), 5)

    def test_cada_componente_paga_su_propio_monto(self):
        objetivo = goals.objetivo_de_la_semana(LUNES)
        objetivo.monedas_pasos = 7
        objetivo.monedas_workouts = 3
        objetivo.save()
        dia(self.mayor, LUNES, 31_000, workouts=2)
        resumen = goals.cerrar_semana(LUNES, HOY)
        self.assertTrue(self._cumplimiento(self.mayor).cumplido)
        self.assertEqual(monedas.saldo(self.mayor, HOY), 10)
        self.assertEqual(resumen["monedas_pagadas"], 10)

    def test_un_componente_que_paga_cero_no_escribe_fila(self):
        objetivo = goals.objetivo_de_la_semana(LUNES)
        objetivo.monedas_workouts = 0
        objetivo.save()
        dia(self.mayor, LUNES, 31_000, workouts=1)
        resumen = goals.cerrar_semana(LUNES, HOY)
        self.assertEqual(MonedaLedger.objects.filter(usuario=self.mayor).count(), 1)
        self.assertEqual(resumen["pagos_workouts"], 0)
        self.assertTrue(self._cumplimiento(self.mayor).cumplido)  # cumplió igual

    def test_la_semana_nueva_copia_las_monedas_editadas(self):
        actual = goals.objetivo_de_la_semana(LUNES)
        actual.monedas_pasos = 8
        actual.save()
        siguiente = goals.objetivo_de_la_semana(HOY)
        self.assertEqual((siguiente.monedas_pasos, siguiente.monedas_workouts), (8, 5))


class MigracionFilasViejasTests(TestCase):
    """La migración 0002 completa las semanas que se cerraron con el modelo viejo."""

    def test_marca_los_dos_componentes_de_las_semanas_cumplidas(self):
        migracion = importlib.import_module("Apps.objetivos.migrations.0002_objetivo_por_componente")
        ana = crear_usuario("ana")
        beto = crear_usuario("beto")
        objetivo = goals.objetivo_de_la_semana(LUNES)
        objetivo.meta_pasos = 30_000
        objetivo.save()
        for usuario, cumplido in ((ana, True), (beto, False)):
            CumplimientoSemanal.objects.create(
                usuario=usuario, objetivo_semanal=objetivo, pasos_semanales=1,
                workouts_acumulados=0, cumplido=cumplido,
            )

        migracion.cargar_metas_y_marcar_cumplidos(registro_apps, None)

        a = CumplimientoSemanal.objects.get(usuario=ana)
        b = CumplimientoSemanal.objects.get(usuario=beto)
        self.assertEqual((a.meta_pasos, a.cumplio_pasos, a.cumplio_workouts), (30_000, True, True))
        self.assertEqual((b.meta_pasos, b.cumplio_pasos, b.cumplio_workouts), (30_000, False, False))
        # Correrla otra vez no duplica la tabla de metas.
        migracion.cargar_metas_y_marcar_cumplidos(registro_apps, None)
        self.assertEqual(MetaPasosPorEdad.objects.count(), 6)


class _ConToken:
    """Usuario con token y el reloj de la vista fijo en la semana 2 de la season 4."""

    url = ""

    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        self.usuario = crear_usuario("ana", nacimiento=date(1980, 5, 1))  # 46 → 45.000
        token = token_de(self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
        reloj = mock.patch("Apps.objetivos.views.hoy", return_value=MIERCOLES_SEMANA_2)
        reloj.start()
        self.addCleanup(reloj.stop)

    def get(self):
        r = self.client.get(self.url)
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def test_sin_token_da_401(self):
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)


class ObjetivosEstadoTests(_ConToken, APITestCase):
    url = "/api/v1/objetivos/estado"

    def test_la_forma_sigue_el_contrato(self):
        datos = self.get()
        self.assertEqual(
            datos["semana"],
            {"numero": 2, "fecha_inicio": "2026-10-05", "fecha_fin": "2026-10-11"},
        )
        self.assertEqual(
            datos["pasos"], {"meta": 45_000, "monedas": 5, "acumulados": 0, "cumplido": False},
        )
        self.assertEqual(
            datos["workouts"],
            {"meta": goals.META_WORKOUTS_INICIAL, "monedas": 5, "acumulados": 0, "cumplido": False},
        )
        self.assertFalse(datos["completada"])
        self.assertEqual(
            datos["season"],
            {
                "numero": 4, "anio": 2026,
                "fecha_inicio": "2026-09-28", "fecha_cierre": "2027-01-03",
                "semanas": 14,
                "dias_para_cierre": 88,
                "aviso_fin_de_season": False,
            },
        )
        self.assertEqual(datos["historial_seasons"], [])

    def test_cada_componente_se_cumple_por_su_lado(self):
        dia(self.usuario, date(2026, 10, 5), 45_000)
        datos = self.get()
        self.assertTrue(datos["pasos"]["cumplido"])
        self.assertFalse(datos["workouts"]["cumplido"])
        self.assertFalse(datos["completada"])

        dia(self.usuario, date(2026, 10, 6), 100, workouts=1)
        datos = self.get()
        self.assertEqual(datos["pasos"]["acumulados"], 45_100)
        self.assertTrue(datos["completada"])

    def test_no_cuenta_otras_semanas_ni_otros_usuarios(self):
        dia(self.usuario, date(2026, 10, 4), 50_000, workouts=3)   # domingo anterior
        dia(crear_usuario("beto"), date(2026, 10, 5), 50_000, workouts=3)
        datos = self.get()
        self.assertEqual((datos["pasos"]["acumulados"], datos["workouts"]["acumulados"]), (0, 0))

    def test_avisa_7_dias_antes_del_fin_de_la_season(self):
        with mock.patch("Apps.objetivos.views.hoy", return_value=date(2026, 12, 28)):
            season = self.get()["season"]
        self.assertEqual(season["dias_para_cierre"], 6)
        self.assertTrue(season["aviso_fin_de_season"])

    def test_la_ruta_vieja_ya_no_existe(self):
        self.assertEqual(self.client.get("/api/v1/retos/estado").status_code, 404)


class ObjetivosSemanasTests(_ConToken, APITestCase):
    url = "/api/v1/objetivos/semanas"

    def _cerrada(self, lunes, pasos, workouts, cumplio_pasos, cumplio_workouts):
        CumplimientoSemanal.objects.create(
            usuario=self.usuario, objetivo_semanal=goals.objetivo_de_la_semana(lunes),
            pasos_semanales=pasos, workouts_acumulados=workouts, meta_pasos=45_000,
            cumplio_pasos=cumplio_pasos, cumplio_workouts=cumplio_workouts,
            cumplido=cumplio_pasos and cumplio_workouts,
        )

    def test_trae_todas_las_semanas_de_la_season(self):
        datos = self.get()
        self.assertEqual(datos["season"]["numero"], 4)
        semanas = datos["semanas"]
        self.assertEqual([s["numero"] for s in semanas], list(range(1, 15)))
        self.assertEqual(semanas[0]["fecha_inicio"], "2026-09-28")
        self.assertEqual(semanas[-1]["fecha_fin"], "2027-01-03")
        self.assertTrue(all(s["patrocinador"] is None for s in semanas))

    def test_estado_de_cada_semana(self):
        self._cerrada(date(2026, 9, 28), 46_000, 0, True, False)
        semanas = self.get()["semanas"]
        self.assertEqual(semanas[0]["estado"], goals.PARCIAL)
        self.assertEqual(semanas[0]["pasos"]["acumulados"], 46_000)
        self.assertTrue(semanas[0]["pasos"]["cumplido"])
        self.assertFalse(semanas[0]["workouts"]["cumplido"])
        self.assertEqual(semanas[1]["estado"], goals.EN_CURSO)
        self.assertEqual({s["estado"] for s in semanas[2:]}, {goals.FUTURA})

    def test_las_semanas_futuras_solo_traen_metas_y_monedas(self):
        futura = self.get()["semanas"][5]
        self.assertEqual(
            futura["pasos"], {"meta": 45_000, "monedas": 5, "acumulados": None, "cumplido": None},
        )
        self.assertIsNone(futura["workouts"]["acumulados"])

    def test_completada_y_no_cumplida(self):
        with mock.patch("Apps.objetivos.views.hoy", return_value=date(2026, 10, 14)):
            self._cerrada(date(2026, 9, 28), 50_000, 1, True, True)
            self._cerrada(date(2026, 10, 5), 1_000, 0, False, False)
            semanas = self.get()["semanas"]
        self.assertEqual(semanas[0]["estado"], goals.COMPLETADA)
        self.assertEqual(semanas[1]["estado"], goals.NO_CUMPLIDA)
        self.assertEqual(semanas[2]["estado"], goals.EN_CURSO)

    def test_semana_pasada_sin_cierre_se_calcula_en_vivo(self):
        # El cron todavía no corrió: la semana 1 sale de los resúmenes diarios.
        dia(self.usuario, date(2026, 9, 29), 45_000, workouts=1)
        semana_1 = self.get()["semanas"][0]
        self.assertEqual(semana_1["estado"], goals.COMPLETADA)
        self.assertEqual(semana_1["pasos"]["acumulados"], 45_000)

    def test_el_lunes_la_semana_que_termino_va_en_revision(self):
        # Lunes 5 oct: la semana 1 (28 sep - 4 oct) sigue en su margen de gracia.
        # Aunque en vivo no esté cumplida, no se dice "no cumplida": su domingo
        # puede llegar todavía. Las cifras van en vivo.
        dia(self.usuario, date(2026, 9, 29), 1_000)
        with mock.patch("Apps.objetivos.views.hoy", return_value=date(2026, 10, 5)):
            semanas = self.get()["semanas"]
        self.assertEqual(semanas[0]["estado"], goals.EN_REVISION)
        self.assertEqual(semanas[0]["pasos"]["acumulados"], 1_000)
        self.assertFalse(semanas[0]["pasos"]["cumplido"])
        self.assertEqual(semanas[1]["estado"], goals.EN_CURSO)

    def test_en_revision_aunque_en_vivo_ya_este_completa(self):
        dia(self.usuario, date(2026, 9, 29), 45_000, workouts=1)
        with mock.patch("Apps.objetivos.views.hoy", return_value=date(2026, 10, 5)):
            semana_1 = self.get()["semanas"][0]
        self.assertEqual(semana_1["estado"], goals.EN_REVISION)
        self.assertTrue(semana_1["pasos"]["cumplido"])

    def test_el_martes_sin_cierre_vuelve_a_calcularse_en_vivo(self):
        # Pasó el margen y el cierre no corrió (falló): el cálculo en vivo de siempre.
        dia(self.usuario, date(2026, 9, 29), 1_000)
        with mock.patch("Apps.objetivos.views.hoy", return_value=date(2026, 10, 6)):
            semana_1 = self.get()["semanas"][0]
        self.assertEqual(semana_1["estado"], goals.NO_CUMPLIDA)

    def test_la_meta_guardada_al_cerrar_manda_sobre_la_actual(self):
        self._cerrada(date(2026, 9, 28), 46_000, 0, True, False)
        MetaPasosPorEdad.objects.filter(edad_desde=40).update(meta_pasos=60_000)
        semanas = self.get()["semanas"]
        self.assertEqual(semanas[0]["pasos"]["meta"], 45_000)   # la que se usó al cerrar
        self.assertEqual(semanas[1]["pasos"]["meta"], 60_000)   # la de ahora
