"""Limpieza antes del servidor (etapa 7, 14 oct 2026)."""
from datetime import date
from importlib import import_module
from io import StringIO
from unittest import mock

from django.apps import apps
from django.contrib.auth.models import User
from django.core.management import CommandError, call_command
from django.db import IntegrityError, transaction
from django.test import TestCase, override_settings

from Apps.liga import models as modelos_liga
from Apps.liga.models import DesgloseLigaMensual, LigaAmigos
from Apps.users.models import Usuario
from services import ligas


def crear_usuario(nombre="ana"):
    user = User.objects.create_user(nombre, password="clave-segura-1")
    return Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=date(1990, 1, 1))


class CodigoViejoBorradoTests(TestCase):
    def test_la_app_rewards_ya_no_esta(self):
        self.assertFalse(apps.is_installed("Apps.rewards"))

    def test_tramo_premio_y_los_campos_de_percentil_ya_no_existen(self):
        self.assertFalse(hasattr(modelos_liga, "TramoPremio"))
        campos = {f.name for f in DesgloseLigaMensual._meta.get_fields()}
        self.assertNotIn("percentil", campos)
        self.assertNotIn("tramo_premio", campos)


class SembrarPruebaTests(TestCase):
    def test_en_el_servidor_se_niega_y_no_crea_nada(self):
        with override_settings(DEBUG=False), self.assertRaises(CommandError) as error:
            call_command("sembrar_prueba", stdout=StringIO())
        self.assertIn("solo para tu computadora", str(error.exception))
        self.assertFalse(User.objects.filter(username="prueba").exists())

    @override_settings(DEBUG=True)
    def test_en_tu_computadora_funciona(self):
        call_command("sembrar_prueba", stdout=StringIO())
        self.assertTrue(User.objects.filter(username="prueba").exists())


class CodigoDeInvitacionUnicoTests(TestCase):
    def setUp(self):
        self.ana = crear_usuario()

    def test_la_base_no_deja_dos_grupos_con_el_mismo_codigo(self):
        LigaAmigos.objects.create(creador_usuario=self.ana, nombre="A", mes=date(2026, 10, 1), codigo_invitacion="ABC234")
        with self.assertRaises(IntegrityError), transaction.atomic():
            LigaAmigos.objects.create(creador_usuario=self.ana, nombre="B", mes=date(2026, 10, 1), codigo_invitacion="ABC234")

    def test_si_el_codigo_sorteado_ya_existe_se_sortea_otro(self):
        ligas.crear_liga(self.ana, "Primera", date(2026, 10, 14))
        usado = LigaAmigos.objects.get().codigo_invitacion
        with mock.patch("services.ligas._codigo", side_effect=[usado, "NUEVO23"]):
            grupo = ligas.crear_liga(self.ana, "Segunda", date(2026, 10, 14))
        self.assertEqual(grupo.codigo_invitacion, "NUEVO23")

    def test_si_dos_grupos_se_crean_a_la_vez_con_el_mismo_codigo_el_segundo_prueba_con_otro(self):
        # La revisión previa no vio el código (otro grupo se creaba en ese instante): la base lo frena.
        ligas.crear_liga(self.ana, "Primera", date(2026, 10, 14))
        usado = LigaAmigos.objects.get().codigo_invitacion
        existe = mock.MagicMock(side_effect=[False, True, False])     # previa, tras el choque, previa del segundo
        filtro = mock.MagicMock(return_value=mock.MagicMock(exists=existe))
        with mock.patch("services.ligas._codigo", side_effect=[usado, "NUEVO23"]), \
                mock.patch.object(LigaAmigos.objects, "filter", filtro):
            grupo = ligas.crear_liga(self.ana, "Segunda", date(2026, 10, 14))
        self.assertEqual(grupo.codigo_invitacion, "NUEVO23")
        self.assertEqual(LigaAmigos.objects.count(), 2)

    def test_si_nunca_logra_un_codigo_libre_falla_en_voz_alta(self):
        ligas.crear_liga(self.ana, "Primera", date(2026, 10, 14))
        usado = LigaAmigos.objects.get().codigo_invitacion
        with mock.patch("services.ligas._codigo", return_value=usado), self.assertRaises(RuntimeError):
            ligas.crear_liga(self.ana, "Segunda", date(2026, 10, 14))


class MigracionDeCodigosTests(TestCase):
    """Si la base ya trae códigos repetidos, la migración se detiene y los lista."""

    def setUp(self):
        self.migracion = import_module("Apps.liga.migrations.0005_limpieza_y_codigo_unico")

    def apps_con(self, filas):
        modelo = mock.MagicMock()
        modelo.objects.values_list.return_value = filas
        falsas = mock.MagicMock()
        falsas.get_model.return_value = modelo
        return falsas

    def test_sin_repetidos_no_hace_nada(self):
        self.migracion.verificar_que_no_haya_codigos_repetidos(self.apps_con([(1, "AAA"), (2, "BBB")]), None)

    def test_con_repetidos_se_detiene_y_dice_cuales(self):
        with self.assertRaises(RuntimeError) as error:
            self.migracion.verificar_que_no_haya_codigos_repetidos(
                self.apps_con([(1, "AAA"), (2, "BBB"), (3, "AAA")]), None,
            )
        self.assertIn("'AAA': [1, 3]", str(error.exception))
