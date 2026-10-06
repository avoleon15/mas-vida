"""Un sync recalcula todos los días que tocan sus muestras (etapa 11, 5 oct 2026)."""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.db.models import Sum
from django.test import SimpleTestCase
from django.utils import timezone
from rest_framework.test import APITestCase

from Apps.activities.models import Muestra, ResumenDiario
from Apps.poincs.models import Ledger, VersionRegla
from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario
from Apps.users.pruebas import token_de
from services.daily_scoring import dias_que_tocan

GT = ZoneInfo("America/Guatemala")
IPHONE = {"fuente_bundle": "com.apple.health", "fuente_nombre": "iPhone", "dispositivo_modelo": "iPhone", "dispositivo_fabricante": "Apple Inc."}
WATCH = {"fuente_bundle": "com.apple.health", "fuente_nombre": "Apple Watch", "dispositivo_modelo": "Watch", "dispositivo_fabricante": "Apple Inc."}


def en_gt(dia, horas):
    return datetime(dia.year, dia.month, dia.day, tzinfo=GT) + timedelta(hours=horas)


class DiasQueTocanTests(SimpleTestCase):
    """La función pura: qué días nombra un paquete de muestras."""

    DESDE, HASTA = date(2026, 9, 21), date(2026, 10, 5)

    def pasos(self, dia, desde, hasta):
        return {"inicio": en_gt(dia, desde), "fin": en_gt(dia, hasta)}

    def tocan(self, pasos=(), sesiones=(), ritmo=()):
        return dias_que_tocan(pasos, sesiones, ritmo, self.DESDE, self.HASTA)

    def test_sin_muestras_no_toca_ningun_dia(self):
        self.assertEqual(self.tocan(), set())

    def test_una_muestra_de_un_dia_toca_ese_dia(self):
        self.assertEqual(self.tocan([self.pasos(date(2026, 10, 4), 8, 8.5)]), {date(2026, 10, 4)})

    def test_una_muestra_que_cruza_la_medianoche_toca_los_dos_dias(self):
        self.assertEqual(
            self.tocan([self.pasos(date(2026, 10, 4), 22, 30)]), {date(2026, 10, 4), date(2026, 10, 5)},
        )

    def test_una_que_termina_justo_a_la_medianoche_no_toca_el_dia_siguiente(self):
        self.assertEqual(self.tocan([self.pasos(date(2026, 10, 4), 20, 24)]), {date(2026, 10, 4)})

    def test_una_lectura_puntual_toca_solo_su_dia(self):
        self.assertEqual(self.tocan([self.pasos(date(2026, 10, 4), 23.5, 23.5)]), {date(2026, 10, 4)})

    def test_una_muestra_de_varios_dias_toca_todos(self):
        self.assertEqual(
            self.tocan([self.pasos(date(2026, 10, 1), 12, 12 + 72)]),
            {date(2026, 10, 1), date(2026, 10, 2), date(2026, 10, 3), date(2026, 10, 4)},
        )

    def test_los_dias_fuera_de_la_ventana_no_cuentan(self):
        self.assertEqual(self.tocan([self.pasos(date(2026, 9, 20), 8, 9)]), set())           # un día antes
        self.assertEqual(self.tocan([self.pasos(date(2026, 9, 21), 8, 9)]), {date(2026, 9, 21)})   # justo el límite
        self.assertEqual(self.tocan([self.pasos(date(2026, 10, 6), 8, 9)]), set())            # mañana

    def test_una_muestra_larguisima_no_recorre_mas_alla_de_la_ventana(self):
        enorme = {"inicio": en_gt(date(2025, 1, 1), 0), "fin": en_gt(date(2027, 1, 1), 0)}
        self.assertEqual(len(self.tocan([enorme])), 15)          # los 15 días de la ventana, no 730

    def test_un_workout_y_el_ritmo_cardiaco_cuentan_en_el_dia_en_que_empiezan(self):
        sesion = {"inicio": en_gt(date(2026, 10, 3), 23), "fin": en_gt(date(2026, 10, 4), 1)}
        ritmo = {"inicio": en_gt(date(2026, 10, 2), 10), "fin": en_gt(date(2026, 10, 2), 10)}
        self.assertEqual(self.tocan(sesiones=[sesion], ritmo=[ritmo]), {date(2026, 10, 3), date(2026, 10, 2)})


class RecalculoPorLaApiTests(APITestCase):
    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        user = get_user_model().objects.create_user("ana@correo.com", password="Clave-segura-2026")
        self.usuario = Usuario.objects.create(user=user, usuario_id="ana-1", birth_date=date(1990, 5, 17))
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(user)}")
        self.hoy = timezone.localdate()
        self.ayer = self.hoy - timedelta(days=1)

    # --- ayudas ---------------------------------------------------------------

    def muestra(self, externo, dia, desde, hasta, cantidad, dispositivo=IPHONE):
        return {
            "external_id": externo, "inicio": en_gt(dia, desde).isoformat(), "fin": en_gt(dia, hasta).isoformat(),
            "cantidad": cantidad, **dispositivo,
        }

    def sesion(self, externo, dia, hora, minutos, promedio, maxima):
        inicio = en_gt(dia, hora)
        return {
            "external_id": externo, "inicio": inicio.isoformat(), "fin": (inicio + timedelta(minutes=minutos)).isoformat(),
            "duracion_min": minutos, "tipo_actividad": "running", "fc_promedio": promedio, "fc_maxima": maxima, **WATCH,
        }

    def sync(self, fecha, pasos=(), sesiones=()):
        r = self.client.post("/api/v1/sync", {
            "fecha": fecha.isoformat(), "zona_horaria": "America/Guatemala",
            "sincronizado_en": en_gt(self.hoy, 22).isoformat(), "app_version": "1.0.0",
            "pasos": list(pasos), "sesiones": list(sesiones), "frecuencia_cardiaca": [],
        }, format="json")
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def puntos(self, dia):
        return Ledger.objects.filter(usuario=self.usuario, fecha=dia).aggregate(t=Sum("puntos"))["t"] or 0

    def resumen(self, dia):
        return ResumenDiario.objects.filter(usuario=self.usuario, fecha=dia).first()

    # --- el hallazgo ---------------------------------------------------------

    def test_una_muestra_de_ayer_que_llega_en_el_sync_de_hoy_recalcula_ayer(self):
        self.sync(self.ayer, [self.muestra("a1", self.ayer, 8, 8.5, 6000)])
        self.assertEqual(self.puntos(self.ayer), 0)                       # 6.000 pasos: menos de 7.000

        r = self.sync(self.hoy, [
            self.muestra("a2", self.ayer, 22, 22.5, 2000),                # llegó tarde, es de ayer
            self.muestra("h1", self.hoy, 8, 8.5, 12000),
        ])
        self.assertEqual(self.puntos(self.ayer), 25)                      # 8.000 pasos
        self.assertEqual(self.resumen(self.ayer).pasos_totales_dia, 8000)
        self.assertEqual(self.resumen(self.ayer).puntos_dia, 25)
        # La respuesta sigue siendo la del día del sync.
        self.assertEqual((r["fecha"], r["pasos_totales_dia"], r["puntos_dia"]), (self.hoy.isoformat(), 12000, 50))

    def test_una_muestra_que_cruza_la_medianoche_actualiza_los_dos_dias_con_un_solo_sync(self):
        r = self.sync(self.hoy, [self.muestra("noche", self.ayer, 22, 30, 8000)])
        self.assertEqual(self.resumen(self.ayer).pasos_totales_dia, 2000)
        self.assertEqual(self.resumen(self.hoy).pasos_totales_dia, 6000)
        self.assertEqual(r["pasos_totales_dia"], 6000)

    def test_un_workout_de_ayer_en_el_sync_de_hoy_cuenta_en_ayer(self):
        # 40 minutos con promedio 135: 70 % de la FCmáx de 183 (128), 100 puntos de intensidad.
        r = self.sync(self.hoy, sesiones=[self.sesion("w1", self.ayer, 18, 40, 135, 160)])
        self.assertEqual(self.resumen(self.ayer).workouts_cantidad, 1)
        self.assertEqual(self.puntos(self.ayer), 100)
        self.assertEqual(r["puntos_dia"], 0)                              # hoy no tuvo nada

    def test_un_paquete_con_varios_dias_los_recalcula_todos(self):
        pasos = [self.muestra(f"d{n}", self.hoy - timedelta(days=n), 8, 8.5, 12000) for n in (1, 2, 3, 4)]
        self.sync(self.hoy, pasos)
        for n in (1, 2, 3, 4):
            with self.subTest(dias_atras=n):
                self.assertEqual(self.puntos(self.hoy - timedelta(days=n)), 50)

    # --- los límites ----------------------------------------------------------

    def test_un_dia_fuera_de_la_ventana_de_14_dias_se_guarda_pero_no_se_recalcula(self):
        viejo = self.hoy - timedelta(days=20)
        self.sync(self.hoy, [self.muestra("viejo", viejo, 8, 8.5, 12000), self.muestra("h", self.hoy, 8, 8.5, 12000)])
        self.assertTrue(Muestra.objects.filter(external_id="viejo").exists())
        self.assertIsNone(self.resumen(viejo))
        self.assertEqual(self.puntos(viejo), 0)

    def test_el_dia_14_atras_si_y_el_15_no(self):
        limite, pasado = self.hoy - timedelta(days=14), self.hoy - timedelta(days=15)
        self.sync(self.hoy, [self.muestra("l", limite, 8, 8.5, 12000), self.muestra("p", pasado, 8, 8.5, 12000)])
        self.assertEqual(self.puntos(limite), 50)
        self.assertIsNone(self.resumen(pasado))

    def test_un_dia_futuro_no_se_recalcula(self):
        manana = self.hoy + timedelta(days=1)
        self.sync(self.hoy, [self.muestra("f", manana, 8, 8.5, 12000)])
        self.assertIsNone(self.resumen(manana))

    def test_un_sync_de_un_solo_dia_no_crea_filas_de_otros_dias(self):
        self.sync(self.hoy, [self.muestra("h", self.hoy, 8, 8.5, 12000)])
        self.assertEqual(ResumenDiario.objects.count(), 1)

    # --- consistencia ---------------------------------------------------------

    def test_repetir_el_mismo_sync_no_agrega_filas_al_ledger(self):
        pasos = [self.muestra("a", self.ayer, 22, 22.5, 8000), self.muestra("b", self.hoy, 8, 8.5, 12000)]
        self.sync(self.hoy, pasos)
        filas = Ledger.objects.count()
        puntos = (self.puntos(self.ayer), self.puntos(self.hoy))
        self.sync(self.hoy, pasos)
        self.assertEqual(Ledger.objects.count(), filas)
        self.assertEqual((self.puntos(self.ayer), self.puntos(self.hoy)), puntos)

    def test_la_correccion_de_otro_dia_es_una_fila_de_ajuste_no_una_edicion(self):
        self.sync(self.ayer, [self.muestra("a1", self.ayer, 8, 8.5, 12000)])         # 50 puntos
        antes = list(Ledger.objects.filter(fecha=self.ayer).values_list("id", "puntos"))
        self.sync(self.hoy, [self.muestra("a2", self.ayer, 20, 20.5, 4000)])          # sube a 16.000 pasos: 100
        despues = Ledger.objects.filter(fecha=self.ayer)
        self.assertTrue(set(antes) <= set(despues.values_list("id", "puntos")))       # nada se editó
        self.assertEqual(self.puntos(self.ayer), 100)
        self.assertTrue(despues.filter(tipo=Ledger.TipoLedger.AJUSTE_MANUAL, puntos=50).exists())

    def test_un_dia_anterior_a_la_verificacion_con_retroactivo_denegado_sigue_anulado(self):
        PolizaVinculada.objects.create(
            usuario=self.usuario, policy_number="P-1", insurer="Demo",
            estado_verificacion=PolizaVinculada.EstadoVerificacion.VERIFICADA,
            birth_date_confirmada=date(1998, 1, 1),                    # se puso 8 años más vieja que la real: mentira
            fecha_verificacion=timezone.now(),
        )
        self.sync(self.hoy, [self.muestra("a", self.ayer, 8, 8.5, 12000)])
        self.assertEqual(self.puntos(self.ayer), 0)
        self.assertEqual(self.resumen(self.ayer).puntos_dia, 0)
        self.assertEqual(self.resumen(self.ayer).pasos_totales_dia, 12000)         # lo caminado queda registrado

    def test_el_sync_de_ayer_con_una_muestra_de_hoy_tambien_recalcula_hoy(self):
        # Un teléfono en otra zona horaria manda la muestra de hoy dentro del paquete de ayer.
        self.sync(self.ayer, [self.muestra("h", self.hoy, 8, 8.5, 12000)])
        self.assertEqual(self.puntos(self.hoy), 50)
