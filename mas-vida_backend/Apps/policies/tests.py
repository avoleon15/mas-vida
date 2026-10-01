from datetime import date, timedelta

from io import StringIO
from pathlib import Path
from unittest import mock

from django.contrib.admin.sites import site
from django.core.management import call_command
from django.contrib.auth.models import User
from django.contrib.messages.storage.fallback import FallbackStorage
from django.test import RequestFactory
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.policies.admin import PolizaVinculadaAdmin
from Apps.policies.models import PolizaVinculada
from Apps.poincs.models import Ledger, VersionRegla
from Apps.users.models import Usuario
from services import monedas, polizas

NACIMIENTO = date(1990, 1, 1)
VINCULAR = "/api/v1/polizas/vincular"
ESTADO = "/api/v1/polizas/estado"
SYNC = "/api/v1/sync"


class PolizaTests(APITestCase):
    def setUp(self):
        self.hoy = timezone.localdate()
        self.user = User.objects.create_user(username="ana", password="clave-segura-1")
        self.usuario = Usuario.objects.create(
            user=self.user, usuario_id="ana-1", birth_date=NACIMIENTO
        )
        VersionRegla.objects.create(version=1, vigente_desde=date(2026, 1, 1))
        token = Token.objects.get(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.datos = {
            "policy_number": "POL-123",
            "insurer": "Seguros Demo GT",
            "birth_date": "1994-03-12",
        }

    def _sync(self, fecha, pasos):
        dia = fecha.isoformat()
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

    def _historia(self):
        """Dos días de actividad previos a la póliza: 50 + 100 = 150 puntos."""
        self._sync(self.hoy - timedelta(days=2), 12000)
        self._sync(self.hoy - timedelta(days=1), 18000)

    def _vincular_y_confirmar(self, nacimiento_confirmado):
        poliza = polizas.vincular(
            self.usuario, "POL-123", "Aseguradora X", date(2026, 1, 1)
        )
        poliza.birth_date_confirmada = nacimiento_confirmado
        poliza.save()
        return poliza

    def _puntos_ano(self):
        return self._sync(self.hoy, 12000)["puntos_ano"]

    # --- endpoints -----------------------------------------------------------

    def test_sin_token_da_401(self):
        self.client.credentials()
        self.assertEqual(self.client.get(ESTADO).status_code, 401)
        self.assertEqual(self.client.post(VINCULAR, self.datos).status_code, 401)

    def test_sin_poliza_el_estado_lo_dice_y_no_desbloquea_nada(self):
        r = self.client.get(ESTADO)
        self.assertEqual(
            r.json(), {"estado": "sin_poliza", "verificada": False, "poliza": None}
        )

    # --- verificación --------------------------------------------------------

    def test_no_se_verifica_sin_la_fecha_que_dio_la_aseguradora(self):
        poliza = polizas.vincular(self.usuario, "POL-123", "X", date(2026, 1, 1))
        with self.assertRaises(polizas.FaltaFechaConfirmada):
            polizas.verificar(poliza)
        poliza.refresh_from_db()
        self.assertEqual(poliza.estado_verificacion, "pendiente")

    def test_rechazada_no_toca_el_ledger_ni_desbloquea(self):
        self._historia()
        antes = Ledger.objects.count()
        poliza = polizas.vincular(self.usuario, "POL-123", "X", date(2026, 1, 1))
        polizas.rechazar(poliza)
        self.assertEqual(Ledger.objects.count(), antes)
        self.assertFalse(polizas.tiene_poliza_verificada(self.usuario))

    def test_coincide_la_fecha_y_el_historico_se_conserva(self):
        self._historia()
        poliza = self._vincular_y_confirmar(NACIMIENTO)
        self.assertEqual(polizas.verificar(poliza), "aplicado")

        self.assertTrue(polizas.tiene_poliza_verificada(self.usuario))
        self.assertFalse(
            Ledger.objects.filter(tipo="retroactivo_denegado").exists()
        )
        # 50 + 100 de los días previos + 50 de hoy.
        self.assertEqual(self._puntos_ano(), 200)

    def test_no_coincide_y_el_historico_se_anula_con_constancia(self):
        self._historia()
        poliza = self._vincular_y_confirmar(date(1991, 1, 1))
        self.assertEqual(polizas.verificar(poliza), "denegado")

        # Una fila negativa por cada día anulado; las originales no se tocan.
        anulaciones = Ledger.objects.filter(tipo="retroactivo_denegado")
        self.assertEqual(sorted(a.puntos for a in anulaciones), [-100, -50])
        self.assertEqual(Ledger.objects.filter(tipo="pasos", puntos=100).count(), 1)

        # Arranca en cero: solo cuenta lo de hoy en adelante.
        self.assertEqual(self._puntos_ano(), 50)

    def test_verificar_dos_veces_no_anula_dos_veces(self):
        self._historia()
        poliza = self._vincular_y_confirmar(date(1991, 1, 1))
        polizas.verificar(poliza)
        poliza.refresh_from_db()
        self.assertEqual(polizas.verificar(poliza), "sin_cambios")
        self.assertEqual(Ledger.objects.filter(tipo="retroactivo_denegado").count(), 2)

    def test_denegar_retroactivo_es_idempotente(self):
        self._historia()
        polizas.denegar_retroactivo(self.usuario, self.hoy)
        self.assertEqual(polizas.denegar_retroactivo(self.usuario, self.hoy), 0)

    def test_dato_tardio_de_un_dia_anulado_no_vuelve_a_sumar(self):
        self._historia()
        polizas.verificar(self._vincular_y_confirmar(date(1991, 1, 1)))

        # Llega tarde más pasos de anteayer, dentro de la ventana de 14 días.
        self._sync(self.hoy - timedelta(days=2), 18000)

        self.assertEqual(self._puntos_ano(), 50)

    def test_dia_nuevo_anterior_al_corte_tampoco_suma(self):
        polizas.verificar(self._vincular_y_confirmar(date(1991, 1, 1)))
        # Primer sync de un día pasado, DESPUÉS de verificar la póliza.
        self._sync(self.hoy - timedelta(days=3), 18000)
        self.assertEqual(self._puntos_ano(), 50)

    def test_pendiente_no_cambia_nada_del_puntaje(self):
        self._historia()
        self._vincular_y_confirmar(date(1991, 1, 1))  # pendiente: no se verificó
        self.assertEqual(self._puntos_ano(), 200)

    def test_con_poliza_verificada_la_edad_sale_de_la_fecha_confirmada(self):
        # Registro dice 1990 (35 años); la aseguradora confirma que tiene 60.
        confirmada = date(self.hoy.year - 60, 1, 1)
        polizas.verificar(self._vincular_y_confirmar(confirmada))
        self.assertEqual(self._sync(self.hoy, 10000)["puntos_pasos"], 75)

    def test_denegar_el_retroactivo_tambien_anula_las_monedas_previas(self):
        monedas.acreditar(
            self.usuario, 20, "objetivo_cumplido", fecha=self.hoy - timedelta(days=3)
        )
        polizas.verificar(self._vincular_y_confirmar(date(1991, 1, 1)))
        self.assertEqual(monedas.saldo(self.usuario, self.hoy), 0)

    def test_las_monedas_ganadas_despues_de_verificar_se_conservan(self):
        polizas.verificar(self._vincular_y_confirmar(date(1991, 1, 1)))
        monedas.acreditar(self.usuario, 20, "objetivo_cumplido", fecha=self.hoy)
        self.assertEqual(monedas.saldo(self.usuario, self.hoy), 20)

    def test_si_la_fecha_coincide_las_monedas_previas_se_conservan(self):
        monedas.acreditar(
            self.usuario, 20, "objetivo_cumplido", fecha=self.hoy - timedelta(days=3)
        )
        polizas.verificar(self._vincular_y_confirmar(NACIMIENTO))
        self.assertEqual(monedas.saldo(self.usuario, self.hoy), 20)

    def test_el_historial_muestra_los_dias_anulados_en_cero(self):
        self._historia()
        polizas.verificar(self._vincular_y_confirmar(date(1991, 1, 1)))
        dias = self.client.get("/api/v1/historial").json()["historial"]
        self.assertEqual([d["puntos_dia"] for d in dias], [0, 0])
        # La actividad sigue visible aunque no sume.
        self.assertEqual(dias[0]["puntos_pasos"], 100)


class PolizaAdminTests(APITestCase):
    def setUp(self):
        user = User.objects.create_user(username="ana", password="clave-segura-1")
        self.usuario = Usuario.objects.create(
            user=user, usuario_id="ana-1", birth_date=NACIMIENTO
        )
        self.admin = PolizaVinculadaAdmin(PolizaVinculada, site)

    def _request(self):
        request = RequestFactory().post("/admin/")
        request.user = User.objects.create_superuser("root", password="x")
        request.session = {}
        request._messages = FallbackStorage(request)
        return request

    def _mensajes(self, request):
        return [str(m) for m in request._messages]

    def test_la_accion_verificar_exige_la_fecha_confirmada(self):
        poliza = polizas.vincular(self.usuario, "POL-1", "X", date(2026, 1, 1))
        request = self._request()
        self.admin.verificar_polizas(request, PolizaVinculada.objects.all())
        poliza.refresh_from_db()
        self.assertEqual(poliza.estado_verificacion, "pendiente")
        self.assertIn("falta la fecha", self._mensajes(request)[0])

    def test_la_accion_verificar_verifica(self):
        poliza = polizas.vincular(self.usuario, "POL-1", "X", date(2026, 1, 1))
        poliza.birth_date_confirmada = NACIMIENTO
        poliza.save()
        self.admin.verificar_polizas(self._request(), PolizaVinculada.objects.all())
        poliza.refresh_from_db()
        self.assertEqual(poliza.estado_verificacion, "verificada")
        self.assertIsNotNone(poliza.fecha_verificacion)

    def test_el_estado_no_se_edita_a_mano_en_el_admin(self):
        self.assertIn("estado_verificacion", self.admin.readonly_fields)

    def test_una_poliza_creada_desde_el_admin_nace_pendiente(self):
        poliza = PolizaVinculada(
            usuario=self.usuario, policy_number="POL-2", insurer="X",
            policy_start_date=date(2026, 1, 1), estado_verificacion="verificada",
        )
        self.admin.save_model(self._request(), poliza, form=None, change=False)
        poliza.refresh_from_db()
        self.assertEqual(poliza.estado_verificacion, "pendiente")


# --- Vinculación automática (dev) + retroactividad ----------------------------

CSV_EJEMPLO = Path(__file__).parent / "fixtures" / "registro_aseguradora.csv"
# Fija el "hoy" de la verificación para que las vigencias del CSV no dependan
# del día en que se corran las pruebas.
HOY_VERIFICACION = date(2026, 9, 30)
POLIZA_ANA = "POL-100001"  # Seguros Demo GT, nacida el 1994-03-12


class VinculacionYRetroactivoTests(APITestCase):
    """El endpoint de verificación automática aplica la regla de retroactividad.

    La fecha de nacimiento del registro (Usuario.birth_date) puede no coincidir
    con la que confirma la aseguradora: ese es el caso que se deniega.
    """

    _sync = PolizaTests._sync
    _historia = PolizaTests._historia

    def setUp(self):
        call_command("cargar_registro_aseguradora", str(CSV_EJEMPLO), stdout=StringIO())
        parche = mock.patch(
            "services.policy_verification._hoy", return_value=HOY_VERIFICACION
        )
        parche.start()
        self.addCleanup(parche.stop)
        self.hoy = timezone.localdate()
        VersionRegla.objects.create(version=1, vigente_desde=date(2026, 1, 1))

    def _cuenta(self, nacimiento):
        user = User.objects.create_user(username="ana", password="clave-segura-1")
        self.usuario = Usuario.objects.create(
            user=user, usuario_id="ana-1", birth_date=nacimiento
        )
        token = Token.objects.get(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def _vincular(self, numero=POLIZA_ANA, nacimiento="1994-03-12"):
        return self.client.post(
            "/api/v1/polizas/vincular",
            {"policy_number": numero, "insurer": "Seguros Demo GT", "birth_date": nacimiento},
            format="json",
        )

    def test_si_la_fecha_coincide_el_historico_se_conserva(self):
        self._cuenta(date(1994, 3, 12))
        self._historia()
        r = self._vincular()
        self.assertEqual(r.json(), {"estado_verificacion": "verificada", "motivo_rechazo": None})
        self.assertFalse(Ledger.objects.filter(tipo="retroactivo_denegado").exists())
        self.assertEqual(self._sync(self.hoy, 12000)["puntos_ano"], 200)

    def test_si_la_fecha_del_registro_no_coincide_se_anula_el_historico(self):
        # Se registró con otra fecha de nacimiento; la aseguradora confirma 1994-03-12.
        self._cuenta(date(1991, 1, 1))
        self._historia()
        r = self._vincular()
        self.assertEqual(r.json()["estado_verificacion"], "verificada")

        anulaciones = Ledger.objects.filter(tipo="retroactivo_denegado")
        self.assertEqual(sorted(a.puntos for a in anulaciones), [-100, -50])
        self.assertEqual(self._sync(self.hoy, 12000)["puntos_ano"], 50)

    def test_una_poliza_rechazada_no_toca_el_ledger(self):
        self._cuenta(date(1991, 1, 1))
        self._historia()
        antes = Ledger.objects.count()
        r = self._vincular(nacimiento="2000-01-01")  # no es la fecha del registro de la aseguradora
        self.assertEqual(r.json()["estado_verificacion"], "rechazada")
        self.assertEqual(Ledger.objects.count(), antes)
        self.assertFalse(polizas.tiene_poliza_verificada(self.usuario))

    def test_el_estado_de_una_poliza_verificada_trae_la_vigencia_de_la_aseguradora(self):
        self._cuenta(date(1994, 3, 12))
        self._vincular()
        r = self.client.get("/api/v1/polizas/estado")
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.json()["verificada"])
        self.assertEqual(r.json()["poliza"]["policy_start_date"], "2026-01-15")

    def test_el_estado_de_una_poliza_pendiente_sin_fecha_de_inicio_no_revienta(self):
        # Una póliza pendiente (o rechazada) todavía no tiene policy_start_date.
        self._cuenta(date(1994, 3, 12))
        PolizaVinculada.objects.create(usuario=self.usuario, policy_number="X-1", insurer="Y")
        r = self.client.get("/api/v1/polizas/estado")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["estado"], "pendiente")
        self.assertIsNone(r.json()["poliza"]["policy_start_date"])

    def test_el_estado_de_una_cuenta_sin_perfil_da_403(self):
        sin_perfil = User.objects.create_user(username="admin2", password="clave-segura-2")
        token = Token.objects.get(user=sin_perfil)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.assertEqual(self.client.get("/api/v1/polizas/estado").status_code, 403)
