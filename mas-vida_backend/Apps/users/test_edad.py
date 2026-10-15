"""Solo mayores de 18 años (6 oct 2026): la regla pura y el registro."""
from datetime import date
from unittest import mock

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase
from rest_framework.test import APITestCase

from Apps.users.models import Usuario
from services.edad import (
    EDAD_MAXIMA, EDAD_MINIMA, MENSAJE_FUTURA, MENSAJE_INVALIDA, MENSAJE_MENOR,
    edad_en, problema_con_la_fecha_de_nacimiento as problema,
)

HOY = date(2026, 10, 6)
REGISTRO = "/api/v1/registro"


class EdadEnTests(SimpleTestCase):
    def test_cuenta_los_anos_cumplidos(self):
        self.assertEqual(edad_en(date(2000, 10, 6), HOY), 26)        # cumple hoy
        self.assertEqual(edad_en(date(2000, 10, 7), HOY), 25)        # cumple mañana
        self.assertEqual(edad_en(date(2000, 10, 5), HOY), 26)        # cumplió ayer

    def test_quien_nacio_un_29_de_febrero_cumple_el_1_de_marzo(self):
        nacimiento = date(2004, 2, 29)
        self.assertEqual(edad_en(nacimiento, date(2026, 2, 28)), 21)
        self.assertEqual(edad_en(nacimiento, date(2026, 3, 1)), 22)
        self.assertEqual(edad_en(nacimiento, date(2028, 2, 29)), 24)


class ReglaDeEdadTests(SimpleTestCase):
    def test_los_limites_son_18_y_120(self):
        self.assertEqual((EDAD_MINIMA, EDAD_MAXIMA), (18, 120))

    def test_cumplir_18_hoy_sirve_y_cumplirlos_manana_no(self):
        self.assertIsNone(problema(date(2008, 10, 6), HOY))
        self.assertEqual(problema(date(2008, 10, 7), HOY), MENSAJE_MENOR)

    def test_un_menor_no_sirve(self):
        self.assertEqual(problema(date(2009, 10, 6), HOY), MENSAJE_MENOR)      # 17
        self.assertEqual(problema(date(2016, 1, 1), HOY), MENSAJE_MENOR)
        self.assertEqual(problema(HOY, HOY), MENSAJE_MENOR)                    # nació hoy

    def test_el_tope_de_120(self):
        self.assertIsNone(problema(date(1906, 10, 6), HOY))                    # cumple 120 hoy
        self.assertIsNone(problema(date(1906, 1, 1), HOY))
        self.assertEqual(problema(date(1905, 10, 6), HOY), MENSAJE_INVALIDA)   # 121
        self.assertEqual(problema(date(1850, 1, 1), HOY), MENSAJE_INVALIDA)
        self.assertEqual(problema(date(1, 1, 1), HOY), MENSAJE_INVALIDA)

    def test_una_fecha_futura_tiene_su_propio_mensaje(self):
        self.assertEqual(problema(date(2026, 10, 7), HOY), MENSAJE_FUTURA)
        self.assertEqual(problema(date(2030, 1, 1), HOY), MENSAJE_FUTURA)

    def test_el_dia_bisiesto_no_rompe_el_borde_de_los_18(self):
        hoy = date(2028, 2, 29)
        self.assertIsNone(problema(date(2010, 2, 28), hoy))                    # 18 cumplidos
        self.assertEqual(problema(date(2010, 3, 1), hoy), MENSAJE_MENOR)       # 17
        self.assertIsNone(problema(date(2008, 2, 29), hoy))                    # 20, nació bisiesto

    def test_sin_fecha_usa_el_dia_de_guatemala(self):
        with mock.patch("services.edad.timezone.localdate", return_value=HOY) as reloj:
            self.assertIsNone(problema(date(2008, 10, 6)))
            self.assertEqual(problema(date(2008, 10, 7)), MENSAJE_MENOR)
        self.assertTrue(reloj.called)


class RegistroConEdadTests(APITestCase):
    def registrar(self, nacimiento):
        with mock.patch("services.edad.timezone.localdate", return_value=HOY):
            return self.client.post(REGISTRO, {
                "username": "ana@correo.com", "password": "Clave-segura-2026",
                "birth_date": nacimiento.isoformat(),
            }, format="json")

    def test_con_18_cumplidos_hoy_se_crea_la_cuenta(self):
        r = self.registrar(date(2008, 10, 6))
        self.assertEqual(r.status_code, 201, r.content)

    def test_un_menor_se_rechaza_con_el_mensaje_de_la_app(self):
        for nacimiento in (date(2008, 10, 7), date(2015, 3, 3), HOY):
            with self.subTest(nacimiento=nacimiento):
                r = self.registrar(nacimiento)
                self.assertEqual(r.status_code, 400)
                self.assertEqual(r.json()["birth_date"], [MENSAJE_MENOR])
        self.assertFalse(get_user_model().objects.filter(username="ana@correo.com").exists())
        self.assertEqual(Usuario.objects.count(), 0)

    def test_una_fecha_absurda_se_rechaza(self):
        for nacimiento in (date(1850, 1, 1), date(1905, 10, 6), date(1, 1, 1)):
            with self.subTest(nacimiento=nacimiento):
                r = self.registrar(nacimiento)
                self.assertEqual(r.status_code, 400)
                self.assertEqual(r.json()["birth_date"], [MENSAJE_INVALIDA])

    def test_una_fecha_futura_conserva_su_mensaje(self):
        r = self.registrar(date(2026, 10, 7))
        self.assertEqual((r.status_code, r.json()["birth_date"]), (400, [MENSAJE_FUTURA]))
