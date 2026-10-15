"""Seasons de 13 semanas ISO (contrato técnico, "Seasons", 2 oct 2026)."""
from datetime import date, timedelta

from django.test import SimpleTestCase, TestCase

from Apps.objetivos.models import Season
from services import goals
from services.tiempo import (
    anio_season,
    fin_semana,
    inicio_semana,
    numero_season,
    rango_season,
)

# Once años: incluye 2026 y 2032 (53 semanas ISO) y varios con la semana 1
# empezando en diciembre.
DESDE, HASTA = date(2024, 1, 1), date(2034, 12, 31)


def todos_los_dias():
    dia = DESDE
    while dia <= HASTA:
        yield dia
        dia += timedelta(days=1)


class SeasonsIsoTests(SimpleTestCase):
    # --- los ejemplos que trae el contrato ---------------------------------

    def test_la_season_4_de_2026_va_del_28_sep_al_3_ene_2027(self):
        for dia in (date(2026, 9, 28), date(2026, 10, 2), date(2026, 12, 31), date(2027, 1, 3)):
            self.assertEqual(rango_season(dia), (date(2026, 9, 28), date(2027, 1, 3)))
            self.assertEqual((anio_season(dia), numero_season(dia)), (2026, 4))

    def test_la_season_4_de_2026_dura_14_semanas(self):
        inicio, fin = rango_season(date(2026, 10, 2))
        self.assertEqual((fin - inicio).days + 1, 14 * 7)

    def test_la_season_1_de_2027_empieza_el_lunes_4_de_enero(self):
        self.assertEqual(rango_season(date(2027, 1, 4))[0], date(2027, 1, 4))
        self.assertEqual((anio_season(date(2027, 1, 4)), numero_season(date(2027, 1, 4))), (2027, 1))

    def test_la_season_1_de_2026_empieza_en_diciembre_de_2025(self):
        # La semana 1 de 2026 es la que contiene el 4 de enero: arranca el 29 dic 2025.
        self.assertEqual(rango_season(date(2025, 12, 29)), (date(2025, 12, 29), date(2026, 3, 29)))
        self.assertEqual(anio_season(date(2025, 12, 29)), 2026)

    # --- fronteras de 2026 ---------------------------------------------------

    def test_fronteras_entre_seasons_de_2026(self):
        esperado = {
            date(2026, 3, 29): 1, date(2026, 3, 30): 2,
            date(2026, 6, 28): 2, date(2026, 6, 29): 3,
            date(2026, 9, 27): 3, date(2026, 9, 28): 4,
        }
        for dia, numero in esperado.items():
            self.assertEqual(numero_season(dia), numero, dia)

    def test_ya_no_corta_en_trimestres_de_calendario(self):
        # Con la regla vieja el 1 de octubre empezaba la season 4; ahora ya estaba
        # corriendo desde el lunes 28 de septiembre.
        self.assertEqual(numero_season(date(2026, 9, 30)), 4)
        self.assertEqual(numero_season(date(2026, 4, 1)), 2)
        self.assertEqual(numero_season(date(2026, 7, 1)), 3)

    # --- reglas que valen para cualquier fecha -------------------------------

    def test_la_season_siempre_contiene_la_fecha(self):
        for dia in todos_los_dias():
            inicio, fin = rango_season(dia)
            self.assertLessEqual(inicio, dia, dia)
            self.assertLessEqual(dia, fin, dia)

    def test_toda_season_empieza_lunes_y_termina_domingo(self):
        for dia in todos_los_dias():
            inicio, fin = rango_season(dia)
            self.assertEqual(inicio.weekday(), 0, dia)
            self.assertEqual(fin.weekday(), 6, dia)

    def test_nunca_parte_una_semana(self):
        for dia in todos_los_dias():
            self.assertEqual(
                rango_season(inicio_semana(dia)), rango_season(fin_semana(dia)), dia
            )

    def test_las_seasons_se_siguen_sin_huecos_ni_solapes(self):
        anterior = None
        for dia in todos_los_dias():
            inicio, fin = rango_season(dia)
            if anterior and (inicio, fin) != anterior:
                self.assertEqual(inicio, anterior[1] + timedelta(days=1), dia)
            anterior = (inicio, fin)

    def test_duran_13_semanas_salvo_la_4_en_anios_de_53(self):
        for dia in todos_los_dias():
            inicio, fin = rango_season(dia)
            semanas = ((fin - inicio).days + 1) // 7
            if numero_season(dia) == 4 and date(anio_season(dia), 12, 28).isocalendar().week == 53:
                self.assertEqual(semanas, 14, dia)
            else:
                self.assertEqual(semanas, 13, dia)

    def test_los_anios_de_53_semanas(self):
        con_53 = {
            anio for anio in range(2024, 2035)
            if date(anio, 12, 28).isocalendar().week == 53
        }
        self.assertEqual(con_53, {2026, 2032})

    def test_la_semana_1_contiene_el_4_de_enero(self):
        for anio in range(2024, 2035):
            cuatro = date(anio, 1, 4)
            inicio, _ = rango_season(cuatro)
            self.assertEqual((anio_season(cuatro), numero_season(cuatro)), (anio, 1))
            self.assertLessEqual(inicio, cuatro)
            self.assertGreater(inicio + timedelta(days=7), cuatro)

    def test_hay_exactamente_cuatro_seasons_por_anio(self):
        for anio in (2026, 2027, 2028):
            numeros = {
                numero_season(dia) for dia in todos_los_dias()
                if anio_season(dia) == anio
            }
            self.assertEqual(numeros, {1, 2, 3, 4})

    def test_el_anio_de_la_season_es_el_anio_iso(self):
        self.assertEqual(anio_season(date(2027, 1, 3)), 2026)  # semana 53 de 2026
        self.assertEqual(anio_season(date(2027, 1, 4)), 2027)
        self.assertEqual(anio_season(date(2024, 12, 30)), 2025)  # semana 1 de 2025


class SeasonDeTests(TestCase):
    """`goals.season_de`: la fila que guarda la season y cómo se corrige."""

    def test_crea_la_fila_con_las_fechas_iso(self):
        season = goals.season_de(date(2026, 10, 2))
        self.assertEqual(
            (season.anio, season.numero, season.fecha_inicio, season.fecha_fin),
            (2026, 4, date(2026, 9, 28), date(2027, 1, 3)),
        )

    def test_los_primeros_dias_de_enero_pertenecen_a_la_season_del_anio_anterior(self):
        a = goals.season_de(date(2026, 12, 1))
        b = goals.season_de(date(2027, 1, 3))
        self.assertEqual(a.pk, b.pk)
        self.assertEqual(Season.objects.count(), 1)

    def test_el_lunes_4_de_enero_empieza_otra_season(self):
        a = goals.season_de(date(2027, 1, 3))
        b = goals.season_de(date(2027, 1, 4))
        self.assertNotEqual(a.pk, b.pk)
        self.assertEqual((b.anio, b.numero), (2027, 1))

    def test_dos_seasons_distintas_son_dos_filas(self):
        goals.season_de(date(2026, 3, 29))
        goals.season_de(date(2026, 3, 30))
        self.assertEqual(Season.objects.count(), 2)

    def test_pedirla_varias_veces_no_duplica(self):
        for _ in range(3):
            goals.season_de(date(2026, 10, 2))
        self.assertEqual(Season.objects.count(), 1)

    def test_corrige_una_fila_guardada_con_la_regla_vieja_de_trimestres(self):
        vieja = Season.objects.create(
            anio=2026, numero=4,
            fecha_inicio=date(2026, 10, 1), fecha_fin=date(2026, 12, 31),
        )
        season = goals.season_de(date(2026, 10, 2))
        vieja.refresh_from_db()
        self.assertEqual(season.pk, vieja.pk)
        self.assertEqual((vieja.fecha_inicio, vieja.fecha_fin), (date(2026, 9, 28), date(2027, 1, 3)))
        self.assertEqual(Season.objects.count(), 1)
