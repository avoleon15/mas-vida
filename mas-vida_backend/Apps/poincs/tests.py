from datetime import date

from django.contrib.auth.models import User
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.poincs.models import Ledger, VersionRegla
from Apps.users.models import Usuario


class HistorialTests(APITestCase):
    url = "/api/v1/historial"

    def setUp(self):
        self.user = User.objects.create_user(username="ana", password="clave-segura-1")
        self.usuario = Usuario.objects.create(
            user=self.user,
            usuario_id="ana-1",
            birth_date=date(1990, 1, 1),
            policy_number="POL-1",
            insurer="Aseguradora",
            policy_start_date=date(2026, 1, 1),
        )
        self.version = VersionRegla.objects.create(version=1, vigente_desde=date(2026, 1, 1))
        # El token lo crea la senal de users al crear el User.
        token = Token.objects.get(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def _ledger(self, fecha, pasos, intensidad, tope=False):
        return Ledger.objects.create(
            usuario=self.usuario,
            fecha=fecha,
            tipo="puntos_diarios",
            puntos=min(pasos + intensidad, 200),
            puntos_pasos=pasos,
            puntos_intensidad=intensidad,
            tope_diario_aplicado=tope,
            version_regla=self.version,
        )

    def test_sin_token_da_401(self):
        self.client.credentials()
        respuesta = self.client.get(self.url)
        self.assertEqual(respuesta.status_code, 401)

    def test_devuelve_los_dias_del_mas_nuevo_al_mas_viejo(self):
        self._ledger(date(2026, 9, 20), 50, 0)
        self._ledger(date(2026, 9, 21), 100, 150, tope=True)

        respuesta = self.client.get(self.url)

        self.assertEqual(respuesta.status_code, 200)
        dias = respuesta.json()["historial"]
        self.assertEqual([d["fecha"] for d in dias], ["2026-09-21", "2026-09-20"])
        self.assertEqual(dias[0], {
            "fecha": "2026-09-21",
            "puntos_pasos": 100,
            "puntos_intensidad": 150,
            "puntos_brutos": 250,
            "puntos_dia": 200,
            "tope_diario_aplicado": True,
            "version_regla": 1,
        })

    def test_filtra_por_rango_de_fechas(self):
        for dia in (18, 19, 20, 21):
            self._ledger(date(2026, 9, dia), 25, 0)

        respuesta = self.client.get(self.url, {"fecha_desde": "2026-09-19", "fecha_hasta": "2026-09-20"})

        fechas = [d["fecha"] for d in respuesta.json()["historial"]]
        self.assertEqual(fechas, ["2026-09-20", "2026-09-19"])

    def test_fecha_mal_escrita_da_400(self):
        respuesta = self.client.get(self.url, {"fecha_desde": "20-09-2026"})
        self.assertEqual(respuesta.status_code, 400)

    def test_rango_al_reves_da_400(self):
        respuesta = self.client.get(self.url, {"fecha_desde": "2026-09-21", "fecha_hasta": "2026-09-20"})
        self.assertEqual(respuesta.status_code, 400)

    def test_no_muestra_los_puntos_de_otro_usuario(self):
        otro = User.objects.create_user(username="beto", password="clave-segura-2")
        otro_usuario = Usuario.objects.create(
            user=otro,
            usuario_id="beto-1",
            birth_date=date(1990, 1, 1),
            policy_number="POL-2",
            insurer="Aseguradora",
            policy_start_date=date(2026, 1, 1),
        )
        Ledger.objects.create(
            usuario=otro_usuario, fecha=date(2026, 9, 21), tipo="puntos_diarios",
            puntos=50, puntos_pasos=50, puntos_intensidad=0, version_regla=self.version,
        )

        respuesta = self.client.get(self.url)

        self.assertEqual(respuesta.json()["historial"], [])
