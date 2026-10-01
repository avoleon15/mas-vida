from datetime import date, timedelta

from django.contrib.admin.sites import site
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
from services import polizas

NACIMIENTO = date(1990, 1, 1)
VINCULAR = "/api/v1/poliza/vincular"
ESTADO = "/api/v1/poliza"
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
            "insurer": "Aseguradora X",
            "policy_start_date": "2026-01-01",
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

    def test_vincular_queda_pendiente_y_no_desbloquea_nada(self):
        r = self.client.post(VINCULAR, self.datos, format="json")
        self.assertEqual(r.status_code, 201)
        self.assertEqual(r.json()["estado"], "pendiente")
        self.assertFalse(r.json()["verificada"])
        self.assertFalse(polizas.tiene_poliza_verificada(self.usuario))

    def test_vincular_dos_veces_da_409(self):
        self.client.post(VINCULAR, self.datos, format="json")
        r = self.client.post(VINCULAR, self.datos, format="json")
        self.assertEqual(r.status_code, 409)
        self.assertEqual(r.json()["error"], "poliza_ya_vinculada")

    def test_vincular_con_campos_faltantes_da_400(self):
        r = self.client.post(VINCULAR, {"insurer": "X"}, format="json")
        self.assertEqual(r.status_code, 400)
        self.assertIn("policy_number", r.json())

    def test_una_rechazada_se_puede_volver_a_enviar(self):
        poliza = polizas.vincular(self.usuario, "VIEJA", "X", date(2026, 1, 1))
        polizas.rechazar(poliza)
        r = self.client.post(VINCULAR, self.datos, format="json")
        self.assertEqual(r.status_code, 201)
        self.assertEqual(r.json()["poliza"]["policy_number"], "POL-123")
        self.assertEqual(PolizaVinculada.objects.filter(usuario=self.usuario).count(), 1)

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
