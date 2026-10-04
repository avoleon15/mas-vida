"""Los ledgers (puntos y monedas) son append-only: se crean filas, nunca se editan."""
from datetime import date
from io import StringIO

from django.contrib.admin.sites import site
from django.contrib.auth.models import User
from django.core.management import call_command
from django.test import RequestFactory, TestCase

from Apps.coins.models import MonedaLedger
from Apps.core.models import FilaInmutable
from Apps.poincs.models import Ledger, VersionRegla
from Apps.users.models import Usuario


class LedgerInmutableTests(TestCase):
    def setUp(self):
        user = User.objects.create_user(username="ana", password="clave-segura-1")
        self.usuario = Usuario.objects.create(
            user=user, usuario_id="ana-1", birth_date=date(1990, 1, 1)
        )
        self.version = VersionRegla.objects.get(version=1)

    def _puntos(self, puntos=50):
        return Ledger.objects.create(
            usuario=self.usuario, fecha=date(2026, 9, 21), tipo="pasos",
            puntos=puntos, version_regla=self.version,
        )

    def _monedas(self, cantidad=5):
        return MonedaLedger.objects.create(
            usuario=self.usuario, fecha=date(2026, 9, 21), tipo="objetivo_cumplido",
            cantidad=cantidad, version_regla=self.version,
        )

    # --- crear sigue funcionando ----------------------------------------------

    def test_crear_filas_funciona(self):
        self._puntos()
        self._monedas()
        self.assertEqual(Ledger.objects.count(), 1)
        self.assertEqual(MonedaLedger.objects.count(), 1)

    def test_get_or_create_no_edita_y_funciona(self):
        self._puntos(50)
        fila, creada = Ledger.objects.get_or_create(
            usuario=self.usuario, fecha=date(2026, 9, 21), tipo="pasos",
            version_regla=self.version, defaults={"puntos": 99},
        )
        self.assertFalse(creada)
        self.assertEqual(fila.puntos, 50)

    # --- editar, actualizar y borrar fallan ------------------------------------

    def test_no_se_puede_editar_una_fila_de_puntos(self):
        fila = self._puntos(50)
        fila.puntos = 200
        with self.assertRaises(FilaInmutable):
            fila.save()
        fila.refresh_from_db()
        self.assertEqual(fila.puntos, 50)

    def test_no_se_puede_editar_una_fila_de_monedas(self):
        fila = self._monedas(5)
        fila.cantidad = 500
        with self.assertRaises(FilaInmutable):
            fila.save()
        fila.refresh_from_db()
        self.assertEqual(fila.cantidad, 5)

    def test_update_en_bloque_falla(self):
        self._puntos(50)
        self._monedas(5)
        with self.assertRaises(FilaInmutable):
            Ledger.objects.filter(usuario=self.usuario).update(puntos=0)
        with self.assertRaises(FilaInmutable):
            MonedaLedger.objects.all().update(cantidad=0)
        self.assertEqual(Ledger.objects.get().puntos, 50)
        self.assertEqual(MonedaLedger.objects.get().cantidad, 5)

    def test_update_or_create_sobre_una_fila_existente_falla(self):
        self._puntos(50)
        with self.assertRaises(FilaInmutable):
            Ledger.objects.update_or_create(
                usuario=self.usuario, fecha=date(2026, 9, 21), tipo="pasos",
                version_regla=self.version, defaults={"puntos": 99},
            )
        self.assertEqual(Ledger.objects.get().puntos, 50)

    def test_borrar_una_fila_falla(self):
        fila = self._puntos()
        moneda = self._monedas()
        with self.assertRaises(FilaInmutable):
            fila.delete()
        with self.assertRaises(FilaInmutable):
            moneda.delete()
        self.assertEqual(Ledger.objects.count(), 1)
        self.assertEqual(MonedaLedger.objects.count(), 1)

    def test_borrar_en_bloque_falla(self):
        self._puntos()
        self._monedas()
        with self.assertRaises(FilaInmutable):
            Ledger.objects.all().delete()
        with self.assertRaises(FilaInmutable):
            MonedaLedger.objects.filter(usuario=self.usuario).delete()
        self.assertEqual(Ledger.objects.count(), 1)
        self.assertEqual(MonedaLedger.objects.count(), 1)

    def test_una_correccion_es_una_fila_nueva(self):
        self._puntos(100)
        Ledger.objects.create(
            usuario=self.usuario, fecha=date(2026, 9, 21), tipo="ajuste_manual",
            puntos=-75, version_regla=self.version,
        )
        total = sum(Ledger.objects.values_list("puntos", flat=True))
        self.assertEqual(total, 25)

    # --- sembrar_prueba no edita -----------------------------------------------

    def test_sembrar_prueba_se_puede_correr_dos_veces(self):
        call_command("sembrar_prueba", stdout=StringIO())
        filas = Ledger.objects.count()
        call_command("sembrar_prueba", stdout=StringIO())
        self.assertEqual(Ledger.objects.count(), filas)


class LedgerAdminTests(TestCase):
    """En el admin se puede ver y agregar, nunca editar ni borrar."""

    def setUp(self):
        self.request = RequestFactory().get("/admin/")
        self.request.user = User.objects.create_superuser("root", password="x")

    def _verificar(self, modelo):
        admin_del_modelo = site._registry[modelo]
        self.assertTrue(admin_del_modelo.has_add_permission(self.request))
        self.assertTrue(admin_del_modelo.has_view_permission(self.request))
        self.assertFalse(admin_del_modelo.has_change_permission(self.request))
        self.assertFalse(admin_del_modelo.has_delete_permission(self.request))

    def test_ledger_de_puntos_solo_ver_y_agregar(self):
        self._verificar(Ledger)

    def test_ledger_de_monedas_solo_ver_y_agregar(self):
        self._verificar(MonedaLedger)

    def test_sin_permiso_de_borrar_no_aparece_la_accion_de_borrar(self):
        acciones = site._registry[Ledger].get_actions(self.request)
        self.assertNotIn("delete_selected", acciones)
