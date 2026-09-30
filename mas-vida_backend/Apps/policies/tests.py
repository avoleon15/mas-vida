import datetime

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.db.models import ProtectedError
from django.test import TestCase
from django.urls import reverse

from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario


def crear_usuario(nombre="ana"):
    user = get_user_model().objects.create_user(nombre, f"{nombre}@example.com", "x")
    return Usuario.objects.create(
        user=user,
        usuario_id=f"id-{nombre}",
        birth_date=datetime.date(1990, 1, 1),
    )


def crear_poliza(usuario, **extra):
    datos = {
        "policy_number": "POL-1",
        "insurer": "Aseguradora A",
        "policy_start_date": datetime.date(2026, 1, 1),
    }
    datos.update(extra)
    return PolizaVinculada.objects.create(usuario=usuario, **datos)


class PolizaVinculadaTests(TestCase):
    # --- Estado de verificación -------------------------------------------

    def test_estado_por_defecto_es_pendiente(self):
        poliza = crear_poliza(crear_usuario())

        self.assertEqual(
            poliza.estado_verificacion,
            PolizaVinculada.EstadoVerificacion.PENDIENTE,
        )
        # Sin integración con la aseguradora todavía: nada confirmado.
        self.assertIsNone(poliza.birth_date_confirmada)
        self.assertIsNone(poliza.fecha_verificacion)
        self.assertIsNotNone(poliza.fecha_vinculacion)

    def test_solo_se_aceptan_los_tres_estados_definidos(self):
        for estado in ("pendiente", "verificada", "rechazada"):
            poliza = crear_poliza(crear_usuario(f"u-{estado}"), estado_verificacion=estado)
            poliza.full_clean()  # no debe lanzar

        invalida = crear_poliza(crear_usuario("u-invalida"), estado_verificacion="aprobada")
        with self.assertRaises(ValidationError):
            invalida.full_clean()

    def test_verificar_una_poliza_guarda_estado_y_fecha(self):
        poliza = crear_poliza(crear_usuario())
        ahora = datetime.datetime(2026, 9, 30, 10, 0, tzinfo=datetime.timezone.utc)

        poliza.estado_verificacion = PolizaVinculada.EstadoVerificacion.VERIFICADA
        poliza.fecha_verificacion = ahora
        poliza.birth_date_confirmada = datetime.date(1990, 1, 1)
        poliza.save()

        poliza.refresh_from_db()
        self.assertEqual(poliza.estado_verificacion, "verificada")
        self.assertEqual(poliza.fecha_verificacion, ahora)
        self.assertEqual(poliza.birth_date_confirmada, datetime.date(1990, 1, 1))

    # --- Una póliza por usuario -------------------------------------------

    def test_un_usuario_solo_puede_tener_una_poliza(self):
        usuario = crear_usuario()
        crear_poliza(usuario)

        # atomic() para que el error no deje rota la transacción del test.
        with self.assertRaises(IntegrityError), transaction.atomic():
            crear_poliza(usuario)

    def test_dos_usuarios_pueden_tener_el_mismo_numero_de_poliza(self):
        # Hoy policy_number no es único. Deja documentado el comportamiento
        # actual (por ejemplo titular y dependiente con la misma póliza). Si
        # más adelante se decide que sea único, este test debe cambiar.
        crear_poliza(crear_usuario("ana"), policy_number="POL-COMPARTIDA")
        crear_poliza(crear_usuario("beto"), policy_number="POL-COMPARTIDA")

        self.assertEqual(
            PolizaVinculada.objects.filter(policy_number="POL-COMPARTIDA").count(),
            2,
        )

    def test_se_puede_vincular_otra_poliza_despues_de_borrar_la_anterior(self):
        usuario = crear_usuario()
        crear_poliza(usuario, policy_number="POL-VIEJA").delete()

        nueva = crear_poliza(usuario, policy_number="POL-NUEVA")

        self.assertEqual(usuario.poliza.pk, nueva.pk)
        self.assertEqual(PolizaVinculada.objects.filter(usuario=usuario).count(), 1)

    # --- PROTECT ----------------------------------------------------------

    def test_no_se_puede_borrar_un_usuario_con_poliza(self):
        usuario = crear_usuario()
        crear_poliza(usuario)

        with self.assertRaises(ProtectedError):
            usuario.delete()

    def test_borrar_la_poliza_no_borra_al_usuario(self):
        usuario = crear_usuario()
        poliza = crear_poliza(usuario)

        poliza.delete()

        self.assertTrue(Usuario.objects.filter(pk=usuario.pk).exists())

    def test_se_puede_borrar_el_usuario_despues_de_borrar_su_poliza(self):
        usuario = crear_usuario()
        crear_poliza(usuario).delete()

        usuario.delete()

        self.assertFalse(Usuario.objects.filter(pk=usuario.pk).exists())

    # --- Acceso entre Usuario y póliza ------------------------------------

    def test_se_accede_a_la_poliza_desde_el_usuario(self):
        usuario = crear_usuario()
        poliza = crear_poliza(usuario)

        self.assertEqual(usuario.poliza, poliza)

    def test_se_accede_al_usuario_desde_la_poliza(self):
        usuario = crear_usuario()
        poliza = crear_poliza(usuario)

        self.assertEqual(poliza.usuario, usuario)

    def test_se_filtran_usuarios_por_estado_de_su_poliza(self):
        ana = crear_usuario("ana")
        beto = crear_usuario("beto")
        crear_poliza(ana, estado_verificacion="verificada")
        crear_poliza(beto, estado_verificacion="pendiente")

        verificados = Usuario.objects.filter(poliza__estado_verificacion="verificada")

        self.assertEqual(list(verificados), [ana])

    # --- Cuenta base (sin póliza) -----------------------------------------

    def test_cuenta_base_no_tiene_poliza(self):
        usuario = crear_usuario()

        # Una cuenta base (sin póliza) es un caso normal, no un error.
        self.assertFalse(PolizaVinculada.objects.filter(usuario=usuario).exists())
        self.assertFalse(hasattr(usuario, "poliza"))

    def test_pedir_la_poliza_de_una_cuenta_base_lanza_does_not_exist(self):
        usuario = crear_usuario()

        with self.assertRaises(PolizaVinculada.DoesNotExist):
            usuario.poliza

    def test_cuentas_con_y_sin_poliza_conviven(self):
        con_poliza = crear_usuario("ana")
        sin_poliza = crear_usuario("beto")
        crear_poliza(con_poliza)

        self.assertEqual(list(Usuario.objects.filter(poliza__isnull=True)), [sin_poliza])
        self.assertEqual(list(Usuario.objects.filter(poliza__isnull=False)), [con_poliza])


class AdminPolizasTests(TestCase):
    """La lista de pólizas del admin sirve para revisar y verificar pólizas."""

    def setUp(self):
        superusuario = get_user_model().objects.create_superuser(
            "admin", "a@example.com", "x"
        )
        self.client.force_login(superusuario)
        self.url = reverse("admin:policies_polizavinculada_changelist")
        crear_poliza(
            crear_usuario("ana"), policy_number="POL-111", estado_verificacion="verificada"
        )
        crear_poliza(
            crear_usuario("beto"), policy_number="POL-222", estado_verificacion="pendiente"
        )

    def test_lista_de_polizas(self):
        respuesta = self.client.get(self.url)

        self.assertEqual(respuesta.status_code, 200)
        self.assertContains(respuesta, "POL-111")
        self.assertContains(respuesta, "POL-222")

    def test_se_filtran_las_polizas_por_estado(self):
        respuesta = self.client.get(self.url, {"estado_verificacion__exact": "verificada"})

        self.assertContains(respuesta, "POL-111")
        self.assertNotContains(respuesta, "POL-222")

    def test_se_buscan_las_polizas_por_numero(self):
        respuesta = self.client.get(self.url, {"q": "POL-222"})

        self.assertContains(respuesta, "POL-222")
        self.assertNotContains(respuesta, "POL-111")
