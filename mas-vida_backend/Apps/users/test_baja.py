"""Baja de cuenta: se borra lo personal y se conserva lo anónimo (etapa 14, 6 oct 2026)."""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from knox.models import AuthToken
from rest_framework.test import APITestCase

from Apps.activities.models import Muestra, MuestraBPM, ResumenDiario, Sesion
from Apps.coins.models import MonedaLedger
from Apps.liga.models import DesgloseLigaMensual, LigaAmigos, LigaMensual, MiembroLigaAmigos
from Apps.objetivos.models import CumplimientoSemanal
from Apps.poincs.models import Ledger, VersionRegla
from Apps.policies.models import CorreccionDeNacimiento, PolizaVinculada
from Apps.users.models import Consentimiento, Usuario
from Apps.users.pruebas import token_de
from services import baja, consentimiento, goals, ligas, monedas

User = get_user_model()
GT = ZoneInfo("America/Guatemala")
CLAVE = "Clave-segura-2026"
VERIFICADA = PolizaVinculada.EstadoVerificacion.VERIFICADA


def version():
    return VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]


def crear_usuario(nombre="ana", nacimiento=date(1990, 5, 17)):
    user = User.objects.create_user(
        f"{nombre}@correo.com", email=f"{nombre}@correo.com", password=CLAVE,
        first_name=nombre.title(), last_name="Martínez",
    )
    return Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=nacimiento)


def poliza(usuario, numero="POL-1"):
    return PolizaVinculada.objects.create(
        usuario=usuario, policy_number=numero, insurer="Seguros Demo", estado_verificacion=VERIFICADA,
        birth_date_confirmada=usuario.birth_date, fecha_verificacion=timezone.now(),
        nombre="Ana", apellido="Martínez", retroactivo="aplicado",
    )


def actividad(usuario, dia=date(2026, 9, 21)):
    """Una muestra de cada tipo con nombres que identifican, un día de resumen, puntos y monedas."""
    inicio = datetime(dia.year, dia.month, dia.day, 8, 0, tzinfo=GT)
    fin = inicio + timedelta(minutes=40)
    comun = dict(usuario=usuario, inicio=inicio, fin=fin, fuente_bundle="com.apple.health",
                 fuente_nombre="iPhone de Ana", dispositivo_nombre="Apple Watch de Ana",
                 dispositivo_modelo="Watch", dispositivo_fabricante="Apple Inc.")
    Muestra.objects.create(external_id="p1", cantidad=8000, **comun)
    MuestraBPM.objects.create(external_id="b1", bpm=120, **comun)
    Sesion.objects.create(external_id="s1", duracion_min=40, fc_promedio=130, fc_maxima=150, **comun)
    ResumenDiario.objects.create(usuario=usuario, fecha=dia, pasos_totales_dia=8000, puntos_dia=25)
    Ledger.objects.create(usuario=usuario, fecha=dia, tipo=Ledger.TipoLedger.PASOS, puntos=25, version_regla=version())
    monedas.acreditar(usuario, 5, MonedaLedger.Tipo.OBJETIVO_CUMPLIDO, fecha=dia)


class LoQueSeBorraTests(TestCase):
    def setUp(self):
        version()
        self.ana = crear_usuario()
        self.ahora = datetime(2026, 10, 6, 10, 0, tzinfo=GT)

    def test_el_acceso_queda_anonimo_e_inutilizable(self):
        self.assertTrue(baja.dar_de_baja(self.ana, self.ahora))
        user = User.objects.get(pk=self.ana.user_id)
        self.assertEqual(user.username, "baja-id-ana")
        self.assertEqual((user.email, user.first_name, user.last_name), ("", "", ""))
        self.assertFalse(user.is_active)
        self.assertFalse(user.has_usable_password())
        self.assertFalse(user.check_password(CLAVE))

    def test_la_fecha_de_nacimiento_queda_en_el_1_de_enero_de_su_anio(self):
        baja.dar_de_baja(self.ana, self.ahora)
        self.ana.refresh_from_db()
        self.assertEqual(self.ana.birth_date, date(1990, 1, 1))
        self.assertEqual(self.ana.dado_de_baja_en, self.ahora)

    def test_el_usuario_id_se_conserva(self):
        baja.dar_de_baja(self.ana, self.ahora)
        self.assertTrue(Usuario.objects.filter(usuario_id="id-ana").exists())

    def test_la_poliza_se_borra_con_sus_correcciones_y_queda_libre(self):
        p = poliza(self.ana)
        CorreccionDeNacimiento.objects.create(poliza=p, fecha_anterior=date(1990, 5, 17), fecha_nueva=date(1990, 5, 18), desde=date(2026, 10, 1))
        baja.dar_de_baja(self.ana, self.ahora)
        self.assertFalse(PolizaVinculada.objects.exists())
        self.assertFalse(CorreccionDeNacimiento.objects.exists())
        # Otra cuenta puede verificar la misma póliza (una póliza, una cuenta verificada).
        poliza(crear_usuario("beto"), numero="POL-1")
        self.assertEqual(PolizaVinculada.objects.filter(policy_number="POL-1", estado_verificacion=VERIFICADA).count(), 1)

    def test_los_nombres_de_fuente_y_dispositivo_se_borran_pero_las_muestras_se_quedan(self):
        actividad(self.ana)
        baja.dar_de_baja(self.ana, self.ahora)
        for modelo in (Muestra, MuestraBPM, Sesion):
            with self.subTest(modelo=modelo.__name__):
                fila = modelo.objects.get(usuario=self.ana)
                self.assertEqual((fila.fuente_nombre, fila.dispositivo_nombre), ("", None))
                # Lo que usa el puntaje sigue igual.
                self.assertEqual(
                    (fila.fuente_bundle, fila.dispositivo_modelo, fila.dispositivo_fabricante),
                    ("com.apple.health", "Watch", "Apple Inc."),
                )
        self.assertEqual(Muestra.objects.get(usuario=self.ana).cantidad, 8000)

    def test_se_cierran_todas_las_sesiones(self):
        token_de(self.ana.user)
        token_de(self.ana.user)
        baja.dar_de_baja(self.ana, self.ahora)
        self.assertFalse(AuthToken.objects.filter(user_id=self.ana.user_id).exists())

    def test_se_revoca_el_consentimiento(self):
        consentimiento.aceptar(self.ana, consentimiento.VERSION_VIGENTE)
        baja.dar_de_baja(self.ana, self.ahora)
        self.assertFalse(consentimiento.vigente(self.ana))
        self.assertEqual(Consentimiento.objects.get(usuario=self.ana).revocado_en, self.ahora)

    def test_dar_de_baja_otra_vez_no_cambia_nada(self):
        baja.dar_de_baja(self.ana, self.ahora)
        self.assertFalse(baja.dar_de_baja(self.ana, self.ahora + timedelta(days=1)))
        self.ana.refresh_from_db()
        self.assertEqual(self.ana.dado_de_baja_en, self.ahora)

    def test_no_toca_a_las_otras_cuentas(self):
        beto = crear_usuario("beto")
        actividad(beto)
        baja.dar_de_baja(self.ana, self.ahora)
        beto.refresh_from_db()
        self.assertEqual(beto.user.username, "beto@correo.com")
        self.assertTrue(beto.user.is_active)
        self.assertEqual(Muestra.objects.get(usuario=beto).fuente_nombre, "iPhone de Ana")


class LoQueSeConservaTests(TestCase):
    def setUp(self):
        version()
        self.ana = crear_usuario()
        actividad(self.ana)

    def test_los_puntos_las_monedas_y_los_resumenes_quedan_igual(self):
        antes = (
            list(Ledger.objects.filter(usuario=self.ana).values_list("pk", "puntos")),
            list(MonedaLedger.objects.filter(usuario=self.ana).values_list("pk", "cantidad")),
            list(ResumenDiario.objects.filter(usuario=self.ana).values_list("fecha", "pasos_totales_dia", "puntos_dia")),
        )
        baja.dar_de_baja(self.ana)
        despues = (
            list(Ledger.objects.filter(usuario=self.ana).values_list("pk", "puntos")),
            list(MonedaLedger.objects.filter(usuario=self.ana).values_list("pk", "cantidad")),
            list(ResumenDiario.objects.filter(usuario=self.ana).values_list("fecha", "pasos_totales_dia", "puntos_dia")),
        )
        self.assertEqual(antes, despues)

    def test_las_muestras_de_salud_se_quedan(self):
        baja.dar_de_baja(self.ana)
        self.assertEqual(
            (Muestra.objects.count(), MuestraBPM.objects.count(), Sesion.objects.count()), (1, 1, 1),
        )


class TusLigasTests(TestCase):
    def setUp(self):
        version()
        self.ana = crear_usuario()
        self.beto = crear_usuario("beto")

    def test_sale_de_sus_grupos_y_el_grupo_sigue_con_los_demas(self):
        grupo = ligas.crear_liga(self.ana, "Oficina", date(2026, 10, 6))
        ligas.unirse(self.beto, grupo.codigo_invitacion, date(2026, 10, 6))
        baja.dar_de_baja(self.ana)
        self.assertTrue(LigaAmigos.objects.filter(pk=grupo.pk).exists())
        self.assertEqual(list(MiembroLigaAmigos.objects.values_list("usuario__usuario_id", flat=True)), ["id-beto"])

    def test_si_era_el_ultimo_el_grupo_se_borra(self):
        grupo = ligas.crear_liga(self.ana, "Solo yo", date(2026, 10, 6))
        baja.dar_de_baja(self.ana)
        self.assertFalse(LigaAmigos.objects.filter(pk=grupo.pk).exists())


class CierresTests(TestCase):
    """Quien se fue ya no entra a La Liga, no cobra el podio pendiente ni se le cierra la semana."""

    def setUp(self):
        version()
        self.ana = crear_usuario()
        self.beto = crear_usuario("beto")
        poliza(self.ana, "POL-A")
        poliza(self.beto, "POL-B")

    def test_deja_de_participar_en_la_liga(self):
        baja.dar_de_baja(self.ana)
        self.assertEqual(list(ligas.participantes_la_liga().values_list("usuario_id", flat=True)), ["id-beto"])

    def test_si_se_va_entre_el_cierre_y_el_pago_no_cobra_el_podio(self):
        Ledger.objects.create(usuario=self.ana, fecha=date(2026, 10, 15), tipo=Ledger.TipoLedger.AJUSTE_MANUAL, puntos=400, version_regla=version())
        Ledger.objects.create(usuario=self.beto, fecha=date(2026, 10, 15), tipo=Ledger.TipoLedger.AJUSTE_MANUAL, puntos=300, version_regla=version())
        ligas.cerrar_la_liga(date(2026, 10, 1), date(2026, 11, 2))
        self.assertEqual(DesgloseLigaMensual.objects.get(usuario=self.ana).monedas, 30)   # el cierre ya lo fijó
        baja.dar_de_baja(self.ana)
        pago = ligas.pagar_la_liga(date(2026, 10, 1), date(2026, 11, 9))
        self.assertEqual(pago["monedas_pagadas"], 20)                                       # solo beto
        self.assertFalse(MonedaLedger.objects.filter(usuario=self.ana, tipo=MonedaLedger.Tipo.LIGA_MENSUAL).exists())
        self.assertTrue(LigaMensual.objects.get(mes=date(2026, 10, 1)).pagada_en)

    def test_no_se_le_cierra_la_semana(self):
        lunes = date(2026, 9, 21)
        for n in range(7):
            ResumenDiario.objects.create(usuario=self.ana, fecha=lunes + timedelta(days=n), pasos_totales_dia=10_000, puntos_dia=0)
        baja.dar_de_baja(self.ana)
        goals.cerrar_semana(lunes, date(2026, 9, 29))
        self.assertFalse(CumplimientoSemanal.objects.filter(usuario=self.ana).exists())
        self.assertTrue(CumplimientoSemanal.objects.filter(usuario=self.beto).exists())


class EndpointTests(APITestCase):
    url = "/api/v1/cuenta/baja"

    def setUp(self):
        version()
        self.ana = crear_usuario()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(self.ana.user)}")

    def pedir(self, password=CLAVE):
        cuerpo = {} if password is None else {"password": password}
        return self.client.post(self.url, cuerpo, format="json")

    def test_con_la_contrasena_correcta_responde_204_y_borra(self):
        r = self.pedir()
        self.assertEqual(r.status_code, 204)
        self.ana.refresh_from_db()
        self.assertIsNotNone(self.ana.dado_de_baja_en)

    def test_despues_el_token_ya_no_sirve(self):
        self.pedir()
        self.assertEqual(self.client.get("/api/v1/perfil").status_code, 401)

    def test_no_se_puede_volver_a_entrar_con_el_correo_ni_con_el_nombre_nuevo(self):
        self.pedir()
        self.client.credentials()
        for nombre in ("ana@correo.com", "baja-id-ana"):
            with self.subTest(nombre=nombre):
                r = self.client.post("/api/v1/login", {"username": nombre, "password": CLAVE}, format="json")
                self.assertEqual(r.status_code, 400)

    def test_el_correo_queda_libre_para_una_cuenta_nueva(self):
        self.pedir()
        self.client.credentials()
        r = self.client.post(
            "/api/v1/registro", {"username": "ana@correo.com", "password": CLAVE, "birth_date": "1990-05-17"}, format="json",
        )
        self.assertEqual(r.status_code, 201, r.content)
        self.assertNotEqual(r.json()["usuario_id"], "id-ana")

    def test_sin_contrasena_responde_400_y_no_borra_nada(self):
        for password in (None, ""):
            with self.subTest(password=password):
                r = self.pedir(password)
                self.assertEqual(r.status_code, 400)
                self.assertIn("password", r.json())
        self.ana.refresh_from_db()
        self.assertIsNone(self.ana.dado_de_baja_en)

    def test_con_la_contrasena_mala_responde_400_y_no_borra_nada(self):
        r = self.pedir("otra-clave-mala")
        self.assertEqual(r.status_code, 400)
        self.assertEqual(r.json(), {"password": ["La contraseña no es correcta."]})
        self.ana.refresh_from_db()
        self.assertIsNone(self.ana.dado_de_baja_en)

    def test_una_contrasena_que_no_es_texto_cuenta_como_incorrecta(self):
        r = self.client.post(self.url, {"password": 12345}, format="json")
        self.assertEqual(r.status_code, 400)
        self.assertEqual(r.json(), {"password": ["La contraseña no es correcta."]})
        self.ana.refresh_from_db()
        self.assertIsNone(self.ana.dado_de_baja_en)

    def test_las_contrasenas_malas_tienen_el_mismo_limite_que_el_login(self):
        for _ in range(5):
            self.pedir("otra-clave-mala")
        r = self.pedir()
        self.assertEqual(r.status_code, 429)
        self.ana.refresh_from_db()
        self.assertIsNone(self.ana.dado_de_baja_en)

    def test_una_cuenta_sin_contrasena_no_la_pide(self):
        self.ana.user.set_unusable_password()
        self.ana.user.save()
        self.assertEqual(self.pedir(None).status_code, 204)

    def test_sin_token_responde_401(self):
        self.client.credentials()
        self.assertEqual(self.pedir().status_code, 401)

    def test_sin_perfil_responde_403(self):
        admin = User.objects.create_user("admin@correo.com", password=CLAVE)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(admin)}")
        self.assertEqual(self.pedir().status_code, 403)

    def test_solo_acepta_post(self):
        self.assertEqual(self.client.get(self.url).status_code, 405)
