"""Año de póliza y cashback en quetzales (paquete 6, 4 oct 2026)."""
from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.poincs.models import Ledger, VersionRegla
from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario
from services import cashback, polizas

NACIMIENTO = date(1990, 1, 1)
VERIFICADA = PolizaVinculada.EstadoVerificacion.VERIFICADA
PENDIENTE = PolizaVinculada.EstadoVerificacion.PENDIENTE
HOY = date(2026, 10, 4)
CASHBACK = "/api/v1/cashback"
SYNC = "/api/v1/sync"


def version():
    return VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]


def crear_usuario(nombre="ana"):
    user = User.objects.create_user(username=nombre, password="clave-segura-1")
    return Usuario.objects.create(user=user, usuario_id=f"{nombre}-1", birth_date=NACIMIENTO)


def poliza(usuario, renovacion, inicio=None, prima="6000.00", estado=VERIFICADA):
    return PolizaVinculada.objects.create(
        usuario=usuario, policy_number=f"P-{usuario.usuario_id}", insurer="Demo",
        estado_verificacion=estado, policy_start_date=inicio,
        fecha_renovacion=renovacion, prima_anual_gtq=Decimal(prima),
        birth_date_confirmada=NACIMIENTO, fecha_verificacion=timezone.now(),
    )


def puntos(usuario, fecha, cantidad):
    Ledger.objects.create(
        usuario=usuario, fecha=fecha, tipo=Ledger.TipoLedger.AJUSTE_MANUAL,
        puntos=cantidad, version_regla=version(),
    )


class AnioDePolizaTests(APITestCase):
    def setUp(self):
        self.usuario = crear_usuario()

    def test_sin_poliza_es_el_anio_calendario(self):
        self.assertEqual(
            polizas.anio_de(self.usuario, HOY), (date(2026, 1, 1), date(2026, 12, 31)),
        )

    def test_pendiente_cuenta_como_sin_poliza(self):
        poliza(self.usuario, date(2027, 3, 1), estado=PENDIENTE)
        self.assertEqual(
            polizas.anio_de(self.usuario, HOY), (date(2026, 1, 1), date(2026, 12, 31)),
        )

    def test_verificada_va_de_aniversario_a_aniversario(self):
        poliza(self.usuario, date(2027, 3, 1))
        self.assertEqual(
            polizas.anio_de(self.usuario, HOY), (date(2026, 3, 1), date(2027, 2, 28)),
        )

    def test_el_dia_de_la_renovacion_ya_es_el_anio_nuevo(self):
        poliza(self.usuario, date(2027, 3, 1))
        self.assertEqual(polizas.anio_de(self.usuario, date(2026, 2, 28))[1], date(2026, 2, 28))
        self.assertEqual(polizas.anio_de(self.usuario, date(2026, 3, 1))[0], date(2026, 3, 1))

    def test_una_fecha_de_renovacion_vieja_se_proyecta_hacia_adelante(self):
        poliza(self.usuario, date(2024, 3, 1))
        self.assertEqual(
            polizas.anio_de(self.usuario, HOY), (date(2026, 3, 1), date(2027, 2, 28)),
        )

    def test_sin_fecha_de_renovacion_usa_el_inicio_de_la_poliza(self):
        poliza(self.usuario, None, inicio=date(2025, 6, 15))
        self.assertEqual(
            polizas.anio_de(self.usuario, HOY), (date(2026, 6, 15), date(2027, 6, 14)),
        )

    def test_renovacion_un_29_de_febrero(self):
        poliza(self.usuario, date(2028, 2, 29))
        self.assertEqual(
            polizas.anio_de(self.usuario, date(2027, 6, 1)), (date(2027, 2, 28), date(2028, 2, 28)),
        )
        self.assertEqual(
            polizas.anio_de(self.usuario, date(2028, 3, 1)), (date(2028, 2, 29), date(2029, 2, 27)),
        )

    def test_los_puntos_de_antes_del_inicio_no_cuentan_para_el_anio_en_curso(self):
        poliza(self.usuario, date(2027, 3, 1))
        puntos(self.usuario, date(2026, 2, 28), 900)   # año anterior
        puntos(self.usuario, date(2026, 3, 1), 100)    # primer día del año en curso
        puntos(self.usuario, date(2026, 9, 1), 250)
        self.assertEqual(polizas.puntos_del_anio(self.usuario, HOY), 350)
        self.assertEqual(polizas.puntos_del_anio(self.usuario, date(2026, 2, 1)), 900)

    def test_al_pasar_al_anio_de_poliza_la_actividad_no_pasa_del_techo(self):
        # Asentado con el año calendario (antes de la póliza): 12.000 en 2026 y
        # 6.000 en enero de 2027. El año de póliza mar 2026–feb 2027 junta los
        # dos, pero cuenta como máximo 12.000.
        puntos(self.usuario, date(2026, 6, 1), 12_000)
        puntos(self.usuario, date(2027, 1, 15), 6_000)
        poliza(self.usuario, date(2027, 3, 1))
        self.assertEqual(polizas.puntos_del_anio(self.usuario, date(2027, 2, 1)), 12_000)

    def test_al_renovar_el_anio_arranca_en_cero(self):
        poliza(self.usuario, date(2027, 3, 1))
        puntos(self.usuario, date(2026, 9, 1), 5000)
        self.assertEqual(polizas.puntos_del_anio(self.usuario, date(2027, 3, 1)), 0)


class TechoAnualPorAnioDePolizaTests(APITestCase):
    def setUp(self):
        self.hoy = timezone.localdate()
        self.usuario = crear_usuario()
        # El año de póliza en curso empezó hace 30 días.
        self.inicio = self.hoy - timedelta(days=30)
        poliza(self.usuario, self.inicio - timedelta(days=365))
        version()
        token = Token.objects.get(user=self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def _sync_hoy(self, pasos):
        dia = self.hoy.isoformat()
        r = self.client.post(SYNC, {
            "fecha": dia,
            "zona_horaria": "America/Guatemala",
            "pasos": [{
                "external_id": f"p-{dia}-{pasos}",
                "inicio": f"{dia}T08:00:00-06:00",
                "fin": f"{dia}T08:30:00-06:00",
                "cantidad": pasos,
                "fuente_bundle": "com.apple.health",
                "fuente_nombre": "Salud",
                "dispositivo_modelo": "iPhone",
            }],
            "sincronizado_en": f"{dia}T20:00:00-06:00",
            "app_version": "1.0.0",
        }, format="json")
        self.assertEqual(r.status_code, 200)
        return r.json()

    def test_lo_del_anio_anterior_no_gasta_el_techo_del_anio_en_curso(self):
        puntos(self.usuario, self.inicio - timedelta(days=5), 11_950)
        r = self._sync_hoy(18000)  # 100 puntos
        self.assertEqual(r["puntos_ano"], 100)
        self.assertFalse(r["tope_anual_aplicado"])

    def test_lo_del_mismo_anio_si_gasta_el_techo(self):
        puntos(self.usuario, self.inicio + timedelta(days=5), 11_950)
        r = self._sync_hoy(18000)
        self.assertEqual(r["puntos_ano"], 12_000)
        self.assertTrue(r["tope_anual_aplicado"])


class CashbackTests(APITestCase):
    def setUp(self):
        self.usuario = crear_usuario()

    def test_sin_poliza_no_hay_prima_ni_monto(self):
        puntos(self.usuario, date(2026, 6, 1), 2600)
        r = cashback.resumen(self.usuario, HOY)
        self.assertFalse(r["con_poliza"])
        self.assertEqual(r["estado"], "sin_poliza")
        self.assertEqual(r["anio"], {"inicio": "2026-01-01", "fin": "2026-12-31", "renovacion": None})
        self.assertEqual((r["puntos_ano"], r["nivel"], r["porcentaje"]), (2600, 1, 5.0))
        self.assertIsNone(r["prima_anual_gtq"])
        self.assertIsNone(r["cashback_gtq"])
        self.assertIsNone(r["siguiente_nivel"]["cashback_gtq"])
        self.assertIsNone(r["anterior"])

    def test_pendiente_se_ve_igual_que_sin_poliza(self):
        poliza(self.usuario, date(2027, 3, 1), estado=PENDIENTE)
        r = cashback.resumen(self.usuario, HOY)
        self.assertFalse(r["con_poliza"])
        self.assertIsNone(r["cashback_gtq"])

    def test_el_monto_es_porcentaje_del_nivel_por_la_prima_anual(self):
        poliza(self.usuario, date(2027, 3, 1), inicio=date(2026, 3, 1))
        puntos(self.usuario, date(2026, 6, 1), 5200)
        r = cashback.resumen(self.usuario, HOY)
        self.assertTrue(r["con_poliza"])
        self.assertEqual(r["estado"], "proyeccion")
        self.assertEqual(r["anio"], {"inicio": "2026-03-01", "fin": "2027-02-28", "renovacion": "2027-03-01"})
        self.assertEqual((r["puntos_ano"], r["nivel"], r["porcentaje"]), (5200, 2, 7.5))
        self.assertEqual(r["prima_anual_gtq"], "6000.00")
        self.assertEqual(r["cashback_gtq"], "450.00")
        self.assertEqual(r["siguiente_nivel"], {
            "nivel": 3, "desde": 10_000, "faltan": 4800, "porcentaje": 10.0, "cashback_gtq": "600.00",
        })
        self.assertIsNone(r["anterior"])

    def test_el_monto_se_redondea_a_centavos(self):
        poliza(self.usuario, date(2027, 3, 1), prima="1234.57")
        puntos(self.usuario, date(2026, 6, 1), 5200)
        # 1234.57 × 7,5 % = 92,59275
        self.assertEqual(cashback.resumen(self.usuario, HOY)["cashback_gtq"], "92.59")

    def test_nivel_0_no_paga(self):
        poliza(self.usuario, date(2027, 3, 1))
        puntos(self.usuario, date(2026, 6, 1), 100)
        r = cashback.resumen(self.usuario, HOY)
        self.assertEqual((r["nivel"], r["porcentaje"], r["cashback_gtq"]), (0, 0.0, "0.00"))

    def test_en_el_ultimo_nivel_no_hay_siguiente(self):
        # Con actividad sola no se pasa de 12.000; el nivel 4 solo llega con
        # el chequeo médico (acreditación manual, fuera de v1).
        poliza(self.usuario, date(2027, 3, 1))
        puntos(self.usuario, date(2026, 6, 1), 12_000)
        Ledger.objects.create(
            usuario=self.usuario, fecha=date(2026, 6, 2), tipo=Ledger.TipoLedger.CHEQUEO_MEDICO,
            puntos=3_000, version_regla=version(),
        )
        r = cashback.resumen(self.usuario, HOY)
        self.assertEqual((r["puntos_ano"], r["nivel"]), (15_000, 4))
        self.assertIsNone(r["siguiente_nivel"])

    def test_poliza_verificada_sin_fechas_no_inventa_renovacion(self):
        poliza(self.usuario, None)
        r = cashback.resumen(self.usuario, HOY)
        self.assertTrue(r["con_poliza"])
        self.assertEqual(r["anio"], {"inicio": "2026-01-01", "fin": "2026-12-31", "renovacion": None})

    def test_el_anio_que_cerro_queda_por_pagar_y_el_nuevo_arranca_en_cero(self):
        poliza(self.usuario, date(2027, 3, 1), inicio=date(2025, 3, 1))
        puntos(self.usuario, date(2025, 8, 1), 2600)
        r = cashback.resumen(self.usuario, HOY)
        self.assertEqual(r["puntos_ano"], 0)
        self.assertEqual(r["anterior"], {
            "inicio": "2025-03-01", "fin": "2026-02-28", "puntos_ano": 2600,
            "nivel": 1, "porcentaje": 5.0, "cashback_gtq": "300.00", "estado": "por_pagar",
        })

    def test_un_anio_cerrado_sin_nivel_no_deja_nada_por_pagar(self):
        poliza(self.usuario, date(2027, 3, 1), inicio=date(2025, 3, 1))
        puntos(self.usuario, date(2025, 8, 1), 100)
        self.assertIsNone(cashback.resumen(self.usuario, HOY)["anterior"])

    def test_no_hay_anio_anterior_si_la_poliza_empezo_en_el_actual(self):
        poliza(self.usuario, date(2027, 3, 1), inicio=date(2026, 3, 1))
        puntos(self.usuario, date(2025, 8, 1), 5000)   # de la cuenta base
        self.assertIsNone(cashback.resumen(self.usuario, HOY)["anterior"])


class CashbackEndpointTests(APITestCase):
    def test_pide_token(self):
        self.assertEqual(self.client.get(CASHBACK).status_code, 401)

    def test_devuelve_el_resumen_del_usuario(self):
        usuario = crear_usuario()
        poliza(usuario, timezone.localdate() + timedelta(days=100))
        token = Token.objects.get(user=usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        r = self.client.get(CASHBACK)
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["con_poliza"])
        self.assertEqual(r.json()["prima_anual_gtq"], "6000.00")

    def test_cuenta_sin_perfil_da_403(self):
        user = User.objects.create_user(username="sinperfil", password="clave-segura-1")
        token = Token.objects.get(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.assertEqual(self.client.get(CASHBACK).status_code, 403)
