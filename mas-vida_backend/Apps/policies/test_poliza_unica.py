"""Una cuenta verificada por póliza (etapa 10, 4 oct 2026)."""
from datetime import date
from decimal import Decimal
from unittest import mock

from django.contrib.admin.sites import site
from django.contrib.auth import get_user_model
from django.contrib.messages.storage.fallback import FallbackStorage
from django.db import IntegrityError, transaction
from django.test import RequestFactory, TestCase
from rest_framework.test import APIClient, APITestCase

from Apps.poincs.models import Ledger, VersionRegla
from Apps.policies.admin import PolizaVinculadaAdmin
from Apps.policies.models import PolizaVinculada, RegistroAseguradora
from Apps.users.models import IntentoFallido, Usuario
from Apps.users.pruebas import token_de
from services import polizas

User = get_user_model()
VERIFICADA = PolizaVinculada.EstadoVerificacion.VERIFICADA
PENDIENTE = PolizaVinculada.EstadoVerificacion.PENDIENTE
RECHAZADA = PolizaVinculada.EstadoVerificacion.RECHAZADA
NACIMIENTO = date(1990, 5, 17)
VINCULAR = "/api/v1/polizas/vincular"
ESTADO = "/api/v1/polizas/estado"


def crear_cuenta(nombre, nacimiento=NACIMIENTO):
    user = User.objects.create_user(f"{nombre}@correo.com", password="Clave-segura-2026")
    usuario = Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=nacimiento)
    cliente = APIClient()
    cliente.credentials(HTTP_AUTHORIZATION=f"Token {token_de(user)}")
    usuario.cliente = cliente
    return usuario


def poliza(usuario, estado=VERIFICADA, numero="POL-X", aseguradora="Seguros Demo", **extra):
    datos = dict(policy_number=numero, insurer=aseguradora, estado_verificacion=estado)
    datos.update(extra)
    return PolizaVinculada.objects.create(usuario=usuario, **datos)


class RestriccionDeLaBaseTests(TestCase):
    """La regla vive en la base de datos, no solo en el código: aguanta dos verificaciones a la vez."""

    def setUp(self):
        self.ana = crear_cuenta("ana")
        self.beto = crear_cuenta("beto")

    def test_dos_cuentas_verificadas_con_la_misma_poliza_no_se_pueden_guardar(self):
        poliza(self.ana)
        with self.assertRaises(IntegrityError), transaction.atomic():
            poliza(self.beto)

    def test_no_distingue_mayusculas_ni_espacios(self):
        poliza(self.ana, numero="POL-X", aseguradora="Seguros Demo")
        with self.assertRaises(IntegrityError), transaction.atomic():
            poliza(self.beto, numero="  pol-x ", aseguradora="seguros demo")

    def test_pendientes_y_rechazadas_si_se_pueden_repetir(self):
        poliza(self.ana, PENDIENTE)
        poliza(self.beto, RECHAZADA)
        self.assertEqual(PolizaVinculada.objects.count(), 2)

    def test_una_verificada_y_otras_pendientes_conviven(self):
        poliza(self.ana, VERIFICADA)
        poliza(self.beto, PENDIENTE)
        self.assertEqual(PolizaVinculada.objects.count(), 2)

    def test_otro_numero_u_otra_aseguradora_no_chocan(self):
        poliza(self.ana, numero="POL-X", aseguradora="Seguros Demo")
        poliza(self.beto, numero="POL-Y", aseguradora="Seguros Demo")
        otra = crear_cuenta("carla")
        poliza(otra, numero="POL-X", aseguradora="Otra Aseguradora")
        self.assertEqual(PolizaVinculada.objects.filter(estado_verificacion=VERIFICADA).count(), 3)

    def test_si_se_borra_la_primera_otra_cuenta_la_puede_verificar(self):
        primera = poliza(self.ana)
        primera.delete()
        poliza(self.beto)
        self.assertEqual(PolizaVinculada.objects.get().usuario, self.beto)


class ServicioVerificarTests(TestCase):
    def setUp(self):
        self.ana = crear_cuenta("ana")
        self.beto = crear_cuenta("beto")
        poliza(self.ana)

    def pendiente_de_beto(self, **extra):
        return poliza(self.beto, PENDIENTE, birth_date_confirmada=NACIMIENTO, **extra)

    def test_verificar_una_poliza_que_ya_es_de_otra_cuenta_lanza_error_y_no_cambia_nada(self):
        pendiente = self.pendiente_de_beto()
        with self.assertRaises(polizas.PolizaEnOtraCuenta):
            polizas.verificar(pendiente)
        pendiente.refresh_from_db()
        self.assertEqual(pendiente.estado_verificacion, PENDIENTE)
        self.assertIsNone(pendiente.fecha_verificacion)

    def test_con_otras_mayusculas_tambien_la_detecta(self):
        pendiente = self.pendiente_de_beto(numero=" pol-x ", aseguradora="SEGUROS DEMO")
        with self.assertRaises(polizas.PolizaEnOtraCuenta):
            polizas.verificar(pendiente)

    def test_la_revision_previa_compara_igual_que_la_base_aun_con_letras_no_ascii(self):
        # Sin depender del respaldo de la restricción: si la revisión previa la detecta,
        # nunca se intenta guardar.
        Ñ = crear_cuenta("ñandu")
        poliza(Ñ, numero="PÓL-Ñ1", aseguradora="SEGUROS ÑANDÚ")
        pendiente = self.pendiente_de_beto(numero="PÓL-Ñ1", aseguradora="SEGUROS ÑANDÚ")
        with mock.patch.object(PolizaVinculada, "save", side_effect=AssertionError("no debía guardar")):
            with self.assertRaises(polizas.PolizaEnOtraCuenta):
                polizas.verificar(pendiente)

    def test_una_poliza_distinta_se_verifica_normal(self):
        pendiente = self.pendiente_de_beto(numero="POL-Y")
        self.assertEqual(polizas.verificar(pendiente), "aplicado")
        pendiente.refresh_from_db()
        self.assertEqual(pendiente.estado_verificacion, VERIFICADA)

    def test_si_la_carrera_se_pierde_en_la_base_tambien_lanza_el_error(self):
        pendiente = self.pendiente_de_beto()
        # Simula que la revisión previa no vio a la otra cuenta (la verificaron a la vez).
        with mock.patch.object(polizas, "_verificada_en_otra_cuenta", return_value=False):
            with self.assertRaises(polizas.PolizaEnOtraCuenta):
                polizas.verificar(pendiente)
        pendiente.refresh_from_db()
        self.assertEqual(pendiente.estado_verificacion, PENDIENTE)

    def test_verificar_la_que_ya_esta_verificada_sigue_siendo_sin_cambios(self):
        propia = PolizaVinculada.objects.get(usuario=self.ana)
        self.assertEqual(polizas.verificar(propia), "sin_cambios")


class VincularPorLaApiTests(APITestCase):
    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        RegistroAseguradora.objects.create(
            numero_poliza="POL-X", aseguradora="Seguros Demo", nombre="Ana", apellido="Martínez",
            fecha_nacimiento=NACIMIENTO, plan="Oro", prima_anual_gtq=Decimal("6000.00"),
            deducible_gtq=Decimal("1000"), coaseguro_pct=20, red="Red A",
            vigencia_inicio=date(2026, 1, 1), vigencia_fin=date(2027, 1, 1), estado="vigente",
        )
        self.ana = crear_cuenta("ana")
        self.gemela = crear_cuenta("gemela")

    def vincular(self, cuenta, numero="POL-X", aseguradora="Seguros Demo", nacimiento="1990-05-17"):
        return cuenta.cliente.post(VINCULAR, {
            "policy_number": numero, "insurer": aseguradora, "birth_date": nacimiento,
        }, format="json")

    def test_la_primera_cuenta_la_verifica(self):
        r = self.vincular(self.ana)
        self.assertEqual((r.status_code, r.json()["estado_verificacion"]), (200, "verificada"))

    def test_la_segunda_cuenta_con_los_mismos_datos_queda_rechazada_con_su_motivo(self):
        self.vincular(self.ana)
        r = self.vincular(self.gemela)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json(), {"estado_verificacion": "rechazada", "motivo_rechazo": "poliza_en_otra_cuenta"})

    def test_la_segunda_cuenta_ve_su_estado_como_rechazada_y_sin_datos_de_la_poliza(self):
        self.vincular(self.ana)
        self.vincular(self.gemela)
        estado = self.gemela.cliente.get(ESTADO).json()
        self.assertEqual((estado["estado"], estado["verificada"], estado["motivo_rechazo"]),
                         ("rechazada", False, "poliza_en_otra_cuenta"))
        self.assertIsNone(estado["poliza"]["nombre"])
        self.assertIsNone(estado["poliza"]["prima_anual_gtq"])

    def test_la_primera_cuenta_no_se_ve_afectada(self):
        self.vincular(self.ana)
        self.vincular(self.gemela)
        estado = self.ana.cliente.get(ESTADO).json()
        self.assertEqual((estado["estado"], estado["poliza"]["nombre"]), ("verificada", "Ana"))

    def test_escribiendo_el_numero_con_otras_mayusculas_tampoco_pasa(self):
        self.vincular(self.ana)
        r = self.vincular(self.gemela, numero=" pol-x ", aseguradora="SEGUROS DEMO")
        self.assertEqual(r.json()["motivo_rechazo"], "poliza_en_otra_cuenta")

    def test_la_segunda_cuenta_no_pierde_su_historial_ni_se_le_aplica_retroactivo(self):
        # La gemela tiene puntos de la cuenta base. Rechazarla por duplicada no los toca.
        version = VersionRegla.objects.get(version=1)
        Ledger.objects.create(
            usuario=self.gemela, fecha=date(2026, 10, 3), tipo=Ledger.TipoLedger.PASOS, puntos=50,
            version_regla=version,
        )
        self.vincular(self.ana)
        self.vincular(self.gemela, nacimiento="1990-05-17")
        self.assertEqual(Ledger.objects.filter(usuario=self.gemela).count(), 1)

    def test_el_rechazo_por_poliza_en_otra_cuenta_no_gasta_intentos(self):
        self.vincular(self.ana)
        for _ in range(8):
            r = self.vincular(self.gemela)
            self.assertEqual(r.status_code, 200)
        self.assertFalse(IntentoFallido.objects.exists())

    def test_un_rechazo_de_la_aseguradora_si_sigue_gastando_intentos(self):
        self.vincular(self.ana)
        self.vincular(self.gemela, nacimiento="1990-05-18")      # fecha mal
        self.assertEqual(IntentoFallido.objects.count(), 2)       # por póliza y por cuenta

    def test_si_la_primera_cuenta_pierde_la_poliza_la_segunda_la_puede_vincular(self):
        self.vincular(self.ana)
        PolizaVinculada.objects.get(usuario=self.ana).delete()    # lo que hará el panel de admin
        r = self.vincular(self.gemela)
        self.assertEqual(r.json()["estado_verificacion"], "verificada")

    def test_quien_fue_rechazado_por_duplicada_puede_reintentar_despues(self):
        self.vincular(self.ana)
        self.vincular(self.gemela)
        PolizaVinculada.objects.get(usuario=self.ana).delete()
        r = self.vincular(self.gemela)
        self.assertEqual(r.json()["estado_verificacion"], "verificada")
        self.assertIsNone(r.json()["motivo_rechazo"])


class AdminVerificarTests(TestCase):
    def setUp(self):
        self.ana = crear_cuenta("ana")
        self.beto = crear_cuenta("beto")
        poliza(self.ana)
        self.pendiente = poliza(self.beto, PENDIENTE, birth_date_confirmada=NACIMIENTO)
        self.admin = PolizaVinculadaAdmin(PolizaVinculada, site)

    def request(self):
        request = RequestFactory().post("/admin/")
        request.user = User.objects.create_superuser("root", password="x")
        request.session = {}
        request._messages = FallbackStorage(request)
        return request

    def test_la_accion_verificar_avisa_y_no_verifica_una_poliza_de_otra_cuenta(self):
        request = self.request()
        self.admin.verificar_polizas(request, PolizaVinculada.objects.filter(pk=self.pendiente.pk))
        self.pendiente.refresh_from_db()
        self.assertEqual(self.pendiente.estado_verificacion, PENDIENTE)
        mensajes = [str(m) for m in request._messages]
        self.assertIn("ya está verificada en otra cuenta", mensajes[0])

    def test_la_accion_sigue_con_las_demas_aunque_una_falle(self):
        carla = crear_cuenta("carla")
        buena = poliza(carla, PENDIENTE, numero="POL-OK", birth_date_confirmada=NACIMIENTO)
        self.admin.verificar_polizas(self.request(), PolizaVinculada.objects.filter(estado_verificacion=PENDIENTE))
        buena.refresh_from_db()
        self.assertEqual(buena.estado_verificacion, VERIFICADA)
