"""Minutos por zona de ritmo cardíaco (etapa 13, 4 oct 2026)."""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase
from django.utils import timezone
from rest_framework.test import APITestCase

from Apps.activities.models import ResumenDiario
from Apps.poincs.models import VersionRegla
from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario
from Apps.users.pruebas import token_de
from services.device import agrupar_por_dispositivo
from services.hearth_rate import minutos_por_zona

GT = ZoneInfo("America/Guatemala")
BASE = datetime(2026, 10, 5, 8, 0, tzinfo=GT)

WATCH = {"fuente_bundle": "com.apple.health", "dispositivo_modelo": "Watch", "dispositivo_fabricante": "Apple Inc."}
FITBIT = {"fuente_bundle": "com.fitbit", "dispositivo_modelo": "Charge", "dispositivo_fabricante": "Fitbit"}


def lectura(minuto, bpm, duracion=1, dispositivo=WATCH, externo=None):
    """Una lectura que empieza en el minuto `minuto` (desde las 8:00) y dura `duracion`."""
    inicio = BASE + timedelta(minutes=minuto)
    return {
        "external_id": externo or f"l-{dispositivo['fuente_bundle']}-{minuto}-{bpm}",
        "inicio": inicio.isoformat(),
        "fin": (inicio + timedelta(minutes=duracion)).isoformat(),
        "bpm": bpm,
        "fuente_nombre": "x", **dispositivo,
    }


def zonas(muestras, edad=36):
    return minutos_por_zona(agrupar_por_dispositivo(muestras), edad)


class MinutosPorZonaTests(SimpleTestCase):
    # A los 36 años la FCmáx es 183: el 60 % es 109,8 y el 70 % es 128,1.

    def test_sin_ritmo_cardiaco_es_none(self):
        self.assertIsNone(zonas([]))

    def test_cada_lectura_va_a_su_zona(self):
        muestras = (
            [lectura(m, 100) for m in range(0, 10)]
            + [lectura(m, 120) for m in range(10, 20)]
            + [lectura(m, 150) for m in range(20, 30)]
        )
        self.assertEqual(zonas(muestras), {"minutos_ligero": 10, "minutos_moderado": 10, "minutos_intenso": 10})

    def test_los_limites_de_las_zonas(self):
        # 109 es ligero; 110 ya es el 60 % (moderado); 128 sigue moderado; 129 es intenso.
        for bpm, zona in ((109, "minutos_ligero"), (110, "minutos_moderado"),
                          (128, "minutos_moderado"), (129, "minutos_intenso")):
            with self.subTest(bpm=bpm):
                resultado = zonas([lectura(0, bpm, duracion=5)])
                self.assertEqual(resultado[zona], 5)
                self.assertEqual(sum(resultado.values()), 5)

    def test_la_edad_mueve_los_umbrales(self):
        # 100 bpm: ligero a los 36 años (FCmáx 183) pero moderado a los 70 (FCmáx 149: 60 % = 89,4).
        muestra = [lectura(0, 100, duracion=5)]
        self.assertEqual(zonas(muestra, edad=36)["minutos_ligero"], 5)
        self.assertEqual(zonas(muestra, edad=70)["minutos_moderado"], 5)

    def test_una_lectura_vale_hasta_que_empieza_la_siguiente(self):
        # Lecturas puntuales cada 5 minutos: cada una cubre sus 5 minutos.
        muestras = [lectura(m, 100, duracion=0) for m in (0, 5, 10)] + [lectura(15, 100, duracion=0)]
        self.assertEqual(zonas(muestras)["minutos_ligero"], 15)

    def test_un_hueco_largo_es_tiempo_sin_dato_y_no_pasa_de_15_minutos(self):
        muestras = [lectura(0, 100, duracion=0), lectura(60, 100, duracion=0)]
        self.assertEqual(zonas(muestras)["minutos_ligero"], 15)

    def test_la_ultima_lectura_vale_lo_que_dura_ella_misma(self):
        self.assertEqual(zonas([lectura(0, 150, duracion=5)])["minutos_intenso"], 5)
        self.assertEqual(zonas([lectura(0, 150, duracion=0)])["minutos_intenso"], 0)

    def test_dos_lecturas_con_la_misma_hora_no_suman_dos_veces(self):
        muestras = [lectura(0, 100, duracion=1, externo="a"), lectura(0, 150, duracion=1, externo="b"),
                    lectura(1, 100, duracion=1)]
        resultado = zonas(muestras)
        # La primera no tiene tiempo propio hasta la siguiente (0 minutos); la segunda cubre 1.
        self.assertEqual(sum(resultado.values()), 2)

    def test_las_lecturas_llegan_en_cualquier_orden(self):
        muestras = [lectura(m, 150) for m in (4, 0, 3, 1, 2)]
        self.assertEqual(zonas(muestras)["minutos_intenso"], 5)

    def test_dos_dispositivos_a_la_vez_no_se_suman(self):
        reloj = [lectura(m, 150, dispositivo=WATCH) for m in range(0, 60)]
        pulsera = [lectura(m, 150, dispositivo=FITBIT) for m in range(0, 30)]
        self.assertEqual(zonas(reloj + pulsera)["minutos_intenso"], 60)

    def test_gana_el_dispositivo_que_cubre_mas_minutos_aunque_tenga_menos_lecturas(self):
        # El reloj lee cada 5 minutos (60 minutos con 12 lecturas); la pulsera, cada minuto durante 20.
        reloj = [lectura(m, 150, duracion=0, dispositivo=WATCH) for m in range(0, 60, 5)]
        pulsera = [lectura(m, 100, dispositivo=FITBIT) for m in range(0, 20)]
        resultado = zonas(reloj + pulsera)
        self.assertEqual((resultado["minutos_intenso"], resultado["minutos_ligero"]), (55, 0))

    def test_un_empate_entre_dispositivos_siempre_da_lo_mismo(self):
        reloj = [lectura(m, 150, dispositivo=WATCH) for m in range(0, 10)]
        pulsera = [lectura(m, 100, dispositivo=FITBIT) for m in range(0, 10)]
        primero = zonas(reloj + pulsera)
        self.assertEqual(primero, zonas(pulsera + reloj))

    def test_el_resultado_son_enteros(self):
        muestras = [lectura(0, 100, duracion=0), lectura(7, 100, duracion=0), lectura(9, 150, duracion=0)]
        for valor in zonas(muestras).values():
            self.assertIsInstance(valor, int)


def crear_usuario(nombre="ana", nacimiento=date(1990, 5, 17)):
    user = get_user_model().objects.create_user(nombre, password="clave-segura-1")
    return Usuario.objects.create(user=user, usuario_id=f"{nombre}-1", birth_date=nacimiento)


class ZonasPorLaApiTests(APITestCase):
    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        self.usuario = crear_usuario()
        token = token_de(self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
        self.hoy = timezone.localdate()

    def _inicio(self, minuto):
        base = datetime.combine(self.hoy, datetime.min.time(), tzinfo=GT) + timedelta(hours=8)
        return base + timedelta(minutes=minuto)

    def _lecturas(self, desde, hasta, bpm, dispositivo=WATCH):
        return [
            {
                "external_id": f"hr-{dispositivo['fuente_bundle']}-{m}-{bpm}",
                "inicio": self._inicio(m).isoformat(), "fin": self._inicio(m + 1).isoformat(),
                "bpm": bpm, "fuente_nombre": "Salud", **dispositivo,
            }
            for m in range(desde, hasta)
        ]

    def _sync(self, lecturas):
        r = self.client.post("/api/v1/sync", {
            "fecha": self.hoy.isoformat(), "zona_horaria": "America/Guatemala",
            "sincronizado_en": self._inicio(600).isoformat(), "app_version": "1.0.0",
            "pasos": [], "sesiones": [], "frecuencia_cardiaca": lecturas,
        }, format="json")
        self.assertEqual(r.status_code, 200, r.content)

    def _resumen(self):
        r = self.client.get("/api/v1/dashboard/resumen", {"desde": self.hoy.isoformat(), "hasta": self.hoy.isoformat()})
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()[0]

    def test_el_resumen_del_dia_trae_los_minutos_por_zona(self):
        self._sync(self._lecturas(0, 30, 100) + self._lecturas(30, 45, 120) + self._lecturas(45, 60, 150))
        self.assertEqual(
            self._resumen()["ritmo_cardiaco"],
            {"minutos_ligero": 30, "minutos_moderado": 15, "minutos_intenso": 15},
        )

    def test_un_dia_sin_ritmo_cardiaco_va_en_null_y_no_en_ceros(self):
        self._sync([])
        self.assertIsNone(self._resumen()["ritmo_cardiaco"])

    def test_un_sync_posterior_con_mas_lecturas_actualiza_el_dia(self):
        self._sync(self._lecturas(0, 10, 100))
        self.assertEqual(self._resumen()["ritmo_cardiaco"]["minutos_ligero"], 10)
        self._sync(self._lecturas(0, 10, 100) + self._lecturas(10, 25, 150))
        self.assertEqual(self._resumen()["ritmo_cardiaco"], {
            "minutos_ligero": 10, "minutos_moderado": 0, "minutos_intenso": 15,
        })

    def test_repetir_el_mismo_sync_no_cambia_los_minutos(self):
        lecturas = self._lecturas(0, 20, 150)
        self._sync(lecturas)
        self._sync(lecturas)
        self.assertEqual(self._resumen()["ritmo_cardiaco"]["minutos_intenso"], 20)

    def test_la_edad_de_la_aseguradora_manda_en_los_umbrales(self):
        # 100 bpm: ligero con la edad del registro (36) y moderado con la confirmada (70 años).
        PolizaVinculada.objects.create(
            usuario=self.usuario, policy_number="P-1", insurer="Demo",
            estado_verificacion=PolizaVinculada.EstadoVerificacion.VERIFICADA,
            birth_date_confirmada=date(self.hoy.year - 70, 1, 1),
        )
        self._sync(self._lecturas(0, 10, 100))
        self.assertEqual(self._resumen()["ritmo_cardiaco"]["minutos_moderado"], 10)

    def test_dos_dispositivos_a_la_vez_no_duplican_los_minutos(self):
        self._sync(self._lecturas(0, 30, 150) + self._lecturas(0, 20, 150, dispositivo=FITBIT))
        self.assertEqual(self._resumen()["ritmo_cardiaco"]["minutos_intenso"], 30)

    def test_las_filas_viejas_sin_zonas_siguen_dando_null(self):
        ResumenDiario.objects.create(usuario=self.usuario, fecha=self.hoy, pasos_totales_dia=8_000, puntos_dia=25)
        self.assertIsNone(self._resumen()["ritmo_cardiaco"])

    def test_los_minutos_de_una_persona_no_salen_en_el_resumen_de_otra(self):
        otra = crear_usuario("beto", date(1985, 1, 1))
        ResumenDiario.objects.create(
            usuario=otra, fecha=self.hoy, pasos_totales_dia=1, puntos_dia=0,
            minutos_ligero=1, minutos_moderado=2, minutos_intenso=3,
        )
        ResumenDiario.objects.create(usuario=self.usuario, fecha=self.hoy, pasos_totales_dia=1, puntos_dia=0)
        self.assertIsNone(self._resumen()["ritmo_cardiaco"])
