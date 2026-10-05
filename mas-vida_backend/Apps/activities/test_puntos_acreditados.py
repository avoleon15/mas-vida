"""Duración de workout coherente y resumen con los puntos acreditados (etapa 11, 5 oct 2026)."""
from datetime import date, datetime, timedelta
from importlib import import_module
from zoneinfo import ZoneInfo

from django.apps import apps
from django.contrib.auth import get_user_model
from django.db.models import Sum
from django.test import SimpleTestCase, TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.activities.models import ResumenDiario, Sesion
from Apps.activities.serializers import duracion_coherente, sesion_plausible
from Apps.poincs.models import Ledger, VersionRegla
from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario

GT = ZoneInfo("America/Guatemala")
WATCH = {"fuente_bundle": "com.apple.health", "fuente_nombre": "Apple Watch", "dispositivo_modelo": "Watch", "dispositivo_fabricante": "Apple Inc."}
IPHONE = {"fuente_bundle": "com.apple.health", "fuente_nombre": "iPhone", "dispositivo_modelo": "iPhone", "dispositivo_fabricante": "Apple Inc."}


def sesion_de(minutos_reales, duracion, segundos_extra=0, promedio=135, maxima=160):
    inicio = datetime(2026, 10, 5, 10, 0, tzinfo=GT)
    return {
        "inicio": inicio,
        "fin": inicio + timedelta(minutes=minutos_reales, seconds=segundos_extra),
        "duracion_min": duracion, "fc_promedio": promedio, "fc_maxima": maxima,
    }


class DuracionCoherenteTests(SimpleTestCase):
    def test_la_duracion_igual_al_tiempo_real_es_valida(self):
        self.assertTrue(duracion_coherente(sesion_de(35, 35)))

    def test_menos_que_el_tiempo_real_es_valido_por_las_pausas(self):
        self.assertTrue(duracion_coherente(sesion_de(60, 48)))

    def test_se_tolera_el_minuto_del_redondeo(self):
        self.assertTrue(duracion_coherente(sesion_de(34, 35, segundos_extra=40)))      # 34 min 40 s se manda como 35
        self.assertTrue(duracion_coherente(sesion_de(35, 35, segundos_extra=1)))

    def test_mas_que_el_tiempo_real_no_es_valido(self):
        self.assertFalse(duracion_coherente(sesion_de(10, 95)))
        self.assertFalse(duracion_coherente(sesion_de(30, 32)))                          # dos minutos de más

    def test_un_minuto_de_mas_sin_segundos_sobrantes_no_pasa(self):
        self.assertFalse(duracion_coherente(sesion_de(35, 36)))

    def test_sin_tiempo_entre_inicio_y_fin_no_hay_duracion_posible(self):
        self.assertFalse(duracion_coherente(sesion_de(0, 30)))

    def test_forma_parte_de_la_plausibilidad_de_la_sesion(self):
        self.assertTrue(sesion_plausible(sesion_de(35, 35)))
        self.assertFalse(sesion_plausible(sesion_de(10, 95)))


def crear_usuario():
    user = get_user_model().objects.create_user("ana@correo.com", password="Clave-segura-2026")
    return Usuario.objects.create(user=user, usuario_id="ana-1", birth_date=date(1990, 5, 17))


class _ConSync(APITestCase):
    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        self.usuario = crear_usuario()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=self.usuario.user).key}")
        self.hoy = timezone.localdate()
        self.ayer = self.hoy - timedelta(days=1)

    def en(self, dia, horas):
        return datetime(dia.year, dia.month, dia.day, tzinfo=GT) + timedelta(hours=horas)

    def pasos(self, externo, dia, cantidad, hora=8):
        return {
            "external_id": externo, "inicio": self.en(dia, hora).isoformat(),
            "fin": self.en(dia, hora + 0.5).isoformat(), "cantidad": cantidad, **IPHONE,
        }

    def sesion(self, externo, dia, minutos_reales, duracion, promedio=135, maxima=160):
        inicio = self.en(dia, 18)
        return {
            "external_id": externo, "inicio": inicio.isoformat(),
            "fin": (inicio + timedelta(minutes=minutos_reales)).isoformat(),
            "duracion_min": duracion, "tipo_actividad": "running",
            "fc_promedio": promedio, "fc_maxima": maxima, **WATCH,
        }

    def sync(self, dia, pasos=(), sesiones=()):
        r = self.client.post("/api/v1/sync", {
            "fecha": dia.isoformat(), "zona_horaria": "America/Guatemala",
            "sincronizado_en": self.en(self.hoy, 22).isoformat(), "app_version": "1.0.0",
            "pasos": list(pasos), "sesiones": list(sesiones), "frecuencia_cardiaca": [],
        }, format="json")
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def resumen(self, dia):
        return ResumenDiario.objects.get(usuario=self.usuario, fecha=dia)

    def credito(self, dia):
        return Ledger.objects.filter(usuario=self.usuario, fecha=dia).aggregate(t=Sum("puntos"))["t"] or 0


class DuracionPorLaApiTests(_ConSync):
    def test_un_workout_de_95_minutos_en_diez_no_da_puntos_y_no_se_guarda(self):
        r = self.sync(self.hoy, sesiones=[self.sesion("falso", self.hoy, 10, 95)])
        self.assertEqual(r["puntos_intensidad"], 0)
        self.assertFalse(Sesion.objects.filter(external_id="falso").exists())

    def test_el_resto_del_paquete_se_acepta_aunque_una_sesion_se_descarte(self):
        r = self.sync(self.hoy, [self.pasos("p", self.hoy, 12000)], [self.sesion("falso", self.hoy, 10, 95)])
        self.assertEqual((r["pasos_totales_dia"], r["puntos_pasos"]), (12000, 50))

    def test_un_workout_con_duracion_coherente_si_cuenta(self):
        # 40 minutos reales y 40 de duración, promedio 135: 70 % de la FCmáx de 183.
        r = self.sync(self.hoy, sesiones=[self.sesion("ok", self.hoy, 40, 40)])
        self.assertEqual(r["puntos_intensidad"], 100)

    def test_con_pausas_cuenta_la_duracion_en_movimiento_y_no_el_tiempo_entre_inicio_y_fin(self):
        # 70 minutos entre inicio y fin pero solo 25 en movimiento: no llega a los 30 que piden los puntos.
        r = self.sync(self.hoy, sesiones=[self.sesion("pausas", self.hoy, 70, 25)])
        self.assertEqual(r["puntos_intensidad"], 0)
        self.assertTrue(Sesion.objects.filter(external_id="pausas").exists())      # la sesión es válida, solo corta


class ResumenAcreditadoTests(_ConSync):
    def test_un_dia_normal_el_resumen_dice_lo_mismo_que_el_ledger(self):
        self.sync(self.hoy, [self.pasos("a", self.hoy, 12000)])
        self.assertEqual((self.resumen(self.hoy).puntos_dia, self.credito(self.hoy)), (50, 50))

    def test_con_el_techo_diario_el_resumen_dice_200(self):
        r = self.sync(self.hoy, [self.pasos("a", self.hoy, 16000)], [self.sesion("w", self.hoy, 95, 95, 120, 150)])
        self.assertEqual(r["puntos_dia"], 200)
        self.assertEqual(self.resumen(self.hoy).puntos_dia, 200)

    def test_pasado_el_techo_anual_el_resumen_dice_lo_acreditado_no_lo_calculado(self):
        version = VersionRegla.objects.get(version=1)
        for i in range(59):                                   # 11.800 puntos ya acreditados en el año...
            dia = self.hoy - timedelta(days=100 + i)
            Ledger.objects.create(usuario=self.usuario, fecha=dia, tipo=Ledger.TipoLedger.PASOS, puntos=200, version_regla=version)
        Ledger.objects.create(                                # ...y 100 más: quedan 100 antes del techo de 12.000
            usuario=self.usuario, fecha=self.hoy - timedelta(days=200), tipo=Ledger.TipoLedger.PASOS,
            puntos=100, version_regla=version,
        )

        r = self.sync(self.hoy, [self.pasos("a", self.hoy, 16000)], [self.sesion("w", self.hoy, 95, 95, 120, 150)])
        self.assertEqual(r["puntos_dia"], 200)                       # lo que calculó el día
        self.assertTrue(r["tope_anual_aplicado"])
        self.assertEqual(self.credito(self.hoy), 100)                # lo que cabía bajo el techo
        self.assertEqual(self.resumen(self.hoy).puntos_dia, 100)

    def test_la_suma_del_resumen_coincide_con_los_puntos_del_ano_de_mi_plan(self):
        version = VersionRegla.objects.get(version=1)
        for i in range(59):
            dia = self.hoy - timedelta(days=100 + i)
            Ledger.objects.create(usuario=self.usuario, fecha=dia, tipo=Ledger.TipoLedger.PASOS, puntos=200, version_regla=version)
            ResumenDiario.objects.create(usuario=self.usuario, fecha=dia, pasos_totales_dia=16000, puntos_dia=200)
        for dia in (self.ayer, self.hoy):                         # estos dos días pasan del techo de 12.000
            self.sync(dia, [self.pasos(f"p{dia}", dia, 16000)], [self.sesion(f"w{dia}", dia, 95, 95, 120, 150)])
        total = self.client.get("/api/v1/dashboard/resumen", {"desde": f"{self.hoy.year}-01-01", "hasta": f"{self.hoy.year}-12-31"}).json()
        progreso = sum(d["puntos_dia"] for d in total)
        mi_plan = self.client.get("/api/v1/cashback").json()["puntos_ano"]
        self.assertEqual(progreso, mi_plan)
        self.assertLessEqual(mi_plan, 12000)

    def test_un_ajuste_por_datos_tardios_se_refleja_en_el_resumen(self):
        self.sync(self.ayer, [self.pasos("a1", self.ayer, 12000)])                     # 50
        self.assertEqual(self.resumen(self.ayer).puntos_dia, 50)
        self.sync(self.hoy, [self.pasos("a2", self.ayer, 4000, hora=20)])                # llega tarde: ayer sube a 100
        self.assertEqual(self.resumen(self.ayer).puntos_dia, 100)

    def test_un_dia_anulado_por_retroactivo_denegado_sigue_en_cero_pero_con_sus_pasos(self):
        PolizaVinculada.objects.create(
            usuario=self.usuario, policy_number="P-1", insurer="Demo",
            estado_verificacion=PolizaVinculada.EstadoVerificacion.VERIFICADA,
            birth_date_confirmada=date(1989, 1, 1), fecha_verificacion=timezone.now(),
        )
        self.sync(self.ayer, [self.pasos("a", self.ayer, 12000)])
        fila = self.resumen(self.ayer)
        self.assertEqual((fila.puntos_dia, fila.pasos_totales_dia), (0, 12000))

    def test_un_dia_sin_actividad_dice_cero(self):
        self.sync(self.hoy, [])
        self.assertEqual(self.resumen(self.hoy).puntos_dia, 0)

    def test_la_respuesta_del_sync_sigue_diciendo_lo_que_calculo_el_dia(self):
        # Contrato: puntos_dia del sync es lo calculado; el resumen y el historial, lo acreditado.
        version = VersionRegla.objects.get(version=1)
        Ledger.objects.create(usuario=self.usuario, fecha=self.ayer, tipo=Ledger.TipoLedger.PASOS, puntos=12000, version_regla=version)
        r = self.sync(self.hoy, [self.pasos("a", self.hoy, 12000)])
        self.assertEqual(r["puntos_dia"], 50)
        self.assertTrue(r["tope_anual_aplicado"])
        self.assertEqual(self.resumen(self.hoy).puntos_dia, 0)


class MigracionDelResumenTests(TestCase):
    def test_realinea_las_filas_viejas_con_el_ledger(self):
        migracion = import_module("Apps.activities.migrations.0007_resumen_puntos_acreditados")
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        usuario = crear_usuario()
        version = VersionRegla.objects.get(version=1)
        dia_pasado, dia_normal, dia_vacio = date(2026, 9, 1), date(2026, 9, 2), date(2026, 9, 3)
        # Pasado el techo: el resumen viejo decía 200 pero el ledger acreditó 0 (cuenta por cuenta).
        ResumenDiario.objects.create(usuario=usuario, fecha=dia_pasado, pasos_totales_dia=1, puntos_dia=200)
        ResumenDiario.objects.create(usuario=usuario, fecha=dia_normal, pasos_totales_dia=1, puntos_dia=50)
        ResumenDiario.objects.create(usuario=usuario, fecha=dia_vacio, pasos_totales_dia=1, puntos_dia=30)
        Ledger.objects.create(usuario=usuario, fecha=dia_pasado, tipo=Ledger.TipoLedger.PASOS, puntos=0, version_regla=version)
        Ledger.objects.create(usuario=usuario, fecha=dia_normal, tipo=Ledger.TipoLedger.PASOS, puntos=50, version_regla=version)
        # Un chequeo médico no es actividad del día.
        Ledger.objects.create(usuario=usuario, fecha=dia_normal, tipo=Ledger.TipoLedger.CHEQUEO_MEDICO, puntos=999, version_regla=version)

        migracion.alinear_con_el_ledger(apps, None)

        valores = dict(ResumenDiario.objects.values_list("fecha", "puntos_dia"))
        self.assertEqual(valores, {dia_pasado: 0, dia_normal: 50, dia_vacio: 0})

    def test_correrla_dos_veces_da_lo_mismo(self):
        migracion = import_module("Apps.activities.migrations.0007_resumen_puntos_acreditados")
        usuario = crear_usuario()
        ResumenDiario.objects.create(usuario=usuario, fecha=date(2026, 9, 1), pasos_totales_dia=1, puntos_dia=200)
        migracion.alinear_con_el_ledger(apps, None)
        migracion.alinear_con_el_ledger(apps, None)
        self.assertEqual(ResumenDiario.objects.get().puntos_dia, 0)
