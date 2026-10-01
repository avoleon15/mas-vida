from datetime import date, timedelta

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.activities.models import Muestra, ResumenDiario
from Apps.poincs.models import Ledger, VersionRegla
from Apps.users.models import Usuario

URL = "/api/v1/sync"
APPLE = {"fuente_bundle": "com.apple.health", "fuente_nombre": "Salud"}
IPHONE = {**APPLE, "dispositivo_modelo": "iPhone", "dispositivo_fabricante": "Apple Inc."}
RELOJ = {
    "fuente_bundle": "com.garmin.connect",
    "fuente_nombre": "Garmin",
    "dispositivo_modelo": "Forerunner",
    "dispositivo_fabricante": "Garmin",
}


def paso(id_, cantidad, hora=8, **fuente):
    return {
        "external_id": id_,
        "inicio": f"{_dia}T{hora:02d}:00:00-06:00",
        "fin": f"{_dia}T{hora:02d}:30:00-06:00",
        "cantidad": cantidad,
        **(fuente or IPHONE),
    }


_dia = ""


class SyncTests(APITestCase):
    def setUp(self):
        global _dia
        self.hoy = timezone.localdate()
        _dia = self.hoy.isoformat()
        self.user = User.objects.create_user(username="ana", password="clave-segura-1")
        self.usuario = Usuario.objects.create(
            user=self.user, usuario_id="ana-1", birth_date=date(1990, 1, 1)
        )
        VersionRegla.objects.create(version=1, vigente_desde=date(2026, 1, 1))
        token = Token.objects.get(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def _payload(self, pasos=(), sesiones=(), bpm=(), fecha=None, **extra):
        return {
            "fecha": (fecha or self.hoy).isoformat(),
            "zona_horaria": "America/Guatemala",
            "pasos": list(pasos),
            "sesiones": list(sesiones),
            "frecuencia_cardiaca": list(bpm),
            "sincronizado_en": f"{_dia}T20:00:00-06:00",
            "app_version": "1.0.0",
            **extra,
        }

    def _sync(self, **kwargs):
        return self.client.post(URL, self._payload(**kwargs), format="json")

    def _sesion(self, id_, minutos, fc, **fuente):
        return {
            "external_id": id_,
            "inicio": f"{_dia}T06:00:00-06:00",
            "fin": f"{_dia}T07:30:00-06:00",
            "duracion_min": minutos,
            "tipo_actividad": "running",
            "fc_promedio": fc,
            "fc_maxima": fc + 10,
            **(fuente or IPHONE),
        }

    def _acreditado(self, fecha=None):
        filas = Ledger.objects.filter(usuario=self.usuario, fecha=fecha or self.hoy)
        return sum(f.puntos for f in filas)

    # --- acceso y validación -------------------------------------------------

    def test_sin_token_da_401(self):
        self.client.credentials()
        self.assertEqual(self._sync().status_code, 401)

    def test_la_identidad_sale_del_token_no_del_cuerpo(self):
        otra = User.objects.create_user(username="beto", password="clave-segura-2")
        beto = Usuario.objects.create(
            user=otra, usuario_id="beto-1", birth_date=date(1990, 1, 1)
        )
        r = self._sync(pasos=[paso("a", 12000)], usuario_id="beto-1")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(Muestra.objects.filter(usuario=beto).count(), 0)
        self.assertEqual(Muestra.objects.filter(usuario=self.usuario).count(), 1)

    def test_campo_faltante_da_400_diciendo_cual(self):
        malo = paso("a", 12000)
        del malo["fuente_bundle"]
        r = self._sync(pasos=[malo])
        self.assertEqual(r.status_code, 400)
        self.assertIn("fuente_bundle", r.json()["pasos[0]"])

    def test_dato_de_hace_mas_de_14_dias_da_422(self):
        vieja = self.hoy - timedelta(days=15)
        r = self._sync(fecha=vieja)
        self.assertEqual(r.status_code, 422)
        self.assertEqual(
            r.json(), {"error": "fuera_de_ventana", "fecha": vieja.isoformat()}
        )

    def test_dato_de_exactamente_14_dias_entra(self):
        self.assertEqual(self._sync(fecha=self.hoy - timedelta(days=14)).status_code, 200)

    def test_muestra_imposible_se_descarta_y_el_resto_entra(self):
        r = self._sync(pasos=[paso("ok", 12000), paso("loca", 900000, hora=9)])
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["pasos_totales_dia"], 12000)
        self.assertEqual(Muestra.objects.count(), 1)

    def test_sesion_sin_tipo_de_actividad_se_acepta(self):
        s = self._sesion("s1", 35, 150)
        s["tipo_actividad"] = None
        self.assertEqual(self._sync(sesiones=[s]).status_code, 200)

    # --- puntos --------------------------------------------------------------

    def test_18000_pasos_dan_100_puntos(self):
        r = self._sync(pasos=[paso("a", 18000)])
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json(), {
            "fecha": self.hoy.isoformat(),
            "puntos_pasos": 100,
            "puntos_intensidad": 0,
            "puntos_dia": 100,
            "tope_diario_aplicado": False,
            "puntos_ano": 100,
            "tope_anual_aplicado": False,
            "nivel": 0,
            "pasos_totales_dia": 18000,
        })

    def test_bajo_7000_pasos_no_da_puntos(self):
        self.assertEqual(self._sync(pasos=[paso("a", 6999)]).json()["puntos_dia"], 0)

    def test_bono_60_suma_25_fijos(self):
        self.usuario.birth_date = date(self.hoy.year - 60, 1, 1)
        self.usuario.save()
        self.assertEqual(self._sync(pasos=[paso("a", 10000)]).json()["puntos_pasos"], 75)

    def test_sesion_intensa_da_puntos_de_intensidad(self):
        # 30 años: FCM 189, 70% = 132. 90 min al 60% o más = 150.
        r = self._sync(sesiones=[self._sesion("s1", 90, 140)])
        self.assertEqual(r.json()["puntos_intensidad"], 150)

    def test_pasos_e_intensidad_se_suman_con_tope_de_200(self):
        r = self._sync(
            pasos=[paso("a", 18000)], sesiones=[self._sesion("s1", 90, 140)]
        ).json()
        self.assertEqual(r["puntos_pasos"], 100)
        self.assertEqual(r["puntos_intensidad"], 150)
        self.assertEqual(r["puntos_dia"], 200)
        self.assertTrue(r["tope_diario_aplicado"])
        self.assertEqual(self._acreditado(), 200)

    def test_llegar_a_exactamente_200_no_cuenta_como_recorte(self):
        # 100 de pasos + 100 de intensidad (60 min al 60%).
        r = self._sync(
            pasos=[paso("a", 18000)], sesiones=[self._sesion("s1", 60, 140)]
        ).json()
        self.assertEqual(r["puntos_dia"], 200)
        self.assertFalse(r["tope_diario_aplicado"])

    # --- idempotencia --------------------------------------------------------

    def test_reenviar_lo_mismo_no_duplica_nada(self):
        payload = dict(pasos=[paso("a", 12000)], sesiones=[self._sesion("s1", 35, 150)])
        primera = self._sync(**payload).json()
        segunda = self._sync(**payload).json()
        self.assertEqual(primera, segunda)
        self.assertEqual(Muestra.objects.count(), 1)
        self.assertEqual(Ledger.objects.filter(usuario=self.usuario).count(), 2)
        self.assertEqual(ResumenDiario.objects.count(), 1)

    # --- precedencia de fuente ----------------------------------------------

    def test_si_hay_reloj_gana_el_reloj_y_no_se_suman_fuentes(self):
        r = self._sync(pasos=[
            paso("tel", 12000),
            paso("rel", 8000, hora=9, **RELOJ),
        ])
        self.assertEqual(r.json()["pasos_totales_dia"], 8000)
        self.assertEqual(r.json()["puntos_pasos"], 25)

    def test_reloj_solo_con_ritmo_cardiaco_tambien_gana(self):
        bpm = {
            "external_id": "b1",
            "inicio": f"{_dia}T10:00:00-06:00",
            "fin": f"{_dia}T10:01:00-06:00",
            "bpm": 120,
            **RELOJ,
        }
        r = self._sync(pasos=[paso("tel", 12000)], bpm=[bpm])
        self.assertEqual(r.json()["pasos_totales_dia"], 0)

    def test_fuente_desconocida_se_trata_como_telefono(self):
        rara = {"fuente_bundle": "com.apps.rara", "fuente_nombre": "Rara"}
        r = self._sync(pasos=[paso("a", 12000, **rara)])
        self.assertEqual(r.json()["pasos_totales_dia"], 12000)

    # --- sync tardío ---------------------------------------------------------

    def test_reloj_que_llega_tarde_corrige_el_dia_con_un_ajuste(self):
        primero = self._sync(pasos=[paso("tel", 18000)]).json()
        self.assertEqual(primero["puntos_dia"], 100)

        tarde = self._sync(pasos=[paso("rel", 8000, hora=9, **RELOJ)]).json()
        self.assertEqual(tarde["pasos_totales_dia"], 8000)
        self.assertEqual(tarde["puntos_dia"], 25)
        self.assertEqual(tarde["puntos_ano"], 25)

        self.assertEqual(self._acreditado(), 25)
        ajuste = Ledger.objects.get(usuario=self.usuario, tipo="ajuste_manual")
        self.assertEqual(ajuste.puntos, -75)
        # Las filas originales no se tocaron.
        self.assertEqual(
            Ledger.objects.get(usuario=self.usuario, tipo="pasos").puntos, 100
        )

    def test_varios_ajustes_el_mismo_dia_quedan_asentados(self):
        self._sync(pasos=[paso("tel", 18000)])           # 100
        self._sync(pasos=[paso("rel", 8000, hora=9, **RELOJ)])   # reloj: 25
        r = self._sync(pasos=[paso("rel2", 4000, hora=10, **RELOJ)])  # 12000: 50
        self.assertEqual(r.json()["puntos_dia"], 50)
        self.assertEqual(self._acreditado(), 50)
        ajustes = Ledger.objects.filter(usuario=self.usuario, tipo="ajuste_manual")
        self.assertEqual(sorted(a.puntos for a in ajustes), [-75, 25])

    def test_repetir_el_sync_tardio_no_duplica_el_ajuste(self):
        self._sync(pasos=[paso("tel", 18000)])
        payload = dict(pasos=[paso("rel", 8000, hora=9, **RELOJ)])
        self._sync(**payload)
        self._sync(**payload)
        self.assertEqual(
            Ledger.objects.filter(usuario=self.usuario, tipo="ajuste_manual").count(), 1
        )
        self.assertEqual(self._acreditado(), 25)

    # --- topes y nivel -------------------------------------------------------

    def _semilla_anual(self, puntos):
        Ledger.objects.create(
            usuario=self.usuario,
            fecha=date(self.hoy.year, 1, 1) if self.hoy != date(self.hoy.year, 1, 1)
            else date(self.hoy.year, 1, 2),
            tipo="ajuste_manual",
            puntos=puntos,
            version_regla=VersionRegla.objects.get(version=1),
        )

    def test_el_tope_anual_de_12000_recorta(self):
        self._semilla_anual(11950)
        r = self._sync(pasos=[paso("a", 18000)]).json()
        self.assertEqual(r["puntos_dia"], 100)
        self.assertEqual(r["puntos_ano"], 12000)
        self.assertTrue(r["tope_anual_aplicado"])
        self.assertEqual(r["nivel"], 3)
        self.assertEqual(self._acreditado(), 50)

    def test_nivel_sale_del_acumulado_anual(self):
        self._semilla_anual(2450)
        r = self._sync(pasos=[paso("a", 18000)]).json()
        self.assertEqual(r["puntos_ano"], 2550)
        self.assertEqual(r["nivel"], 1)

    # --- resumen diario ------------------------------------------------------

    def test_guarda_el_resumen_diario(self):
        self._sync(pasos=[paso("a", 12000)], sesiones=[self._sesion("s1", 35, 150)])
        resumen = ResumenDiario.objects.get(usuario=self.usuario, fecha=self.hoy)
        self.assertEqual(resumen.pasos_totales_dia, 12000)
        self.assertEqual(resumen.workouts_cantidad, 1)
        self.assertEqual(resumen.workouts_duracion_total_min, 35)
        self.assertEqual(resumen.workouts_fc_promedio, 150)
        self.assertEqual(resumen.workouts_fc_maxima, 160)

    def test_sin_sesion_el_resumen_guarda_null_no_cero(self):
        self._sync(pasos=[paso("a", 12000)])
        resumen = ResumenDiario.objects.get(usuario=self.usuario, fecha=self.hoy)
        self.assertIsNone(resumen.workouts_cantidad)

    def test_sin_version_de_regla_responde_500_claro(self):
        VersionRegla.objects.all().delete()
        r = self._sync(pasos=[paso("a", 12000)])
        self.assertEqual(r.status_code, 500)
