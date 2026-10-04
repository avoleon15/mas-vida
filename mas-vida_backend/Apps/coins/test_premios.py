"""Premios, canje y cupones: servicio y endpoints (paquete 4, 3 oct 2026)."""
import importlib
import json
import os
import tempfile
from datetime import date, timedelta
from io import StringIO
from unittest import mock

from django.apps import apps as registro_apps
from django.contrib.auth.models import User
from django.core.management import CommandError, call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.coins.models import Canje, MonedaLedger, Premio
from Apps.objetivos.models import CumplimientoSemanal
from Apps.poincs.models import VersionRegla
from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario
from services import goals, monedas, premios
from services.tiempo import hoy

GANAR = MonedaLedger.Tipo.OBJETIVO_CUMPLIDO


def crear_usuario(nombre="ana"):
    user = User.objects.create_user(username=nombre, password="clave-segura-1")
    return Usuario.objects.create(user=user, usuario_id=f"{nombre}-1", birth_date=date(1990, 1, 1))


def verificar(usuario, estado=PolizaVinculada.EstadoVerificacion.VERIFICADA):
    return PolizaVinculada.objects.create(
        usuario=usuario, policy_number=f"P-{usuario.pk}", insurer="Demo", estado_verificacion=estado,
    )


def crear_premio(nombre="Ookii", costo=40, **extra):
    datos = dict(
        nombre=nombre, descripcion="2x1 en sushi", costo_monedas=costo,
        comercio_aliado=nombre, categoria="Restaurantes",
    )
    datos.update(extra)
    return Premio.objects.create(**datos)


def crear_cupon(usuario, premio, dias_para_vencer=30, estado=Canje.Estado.ACTIVO, **extra):
    datos = dict(
        usuario=usuario, premio=premio, costo_monedas=premio.costo_monedas,
        fecha_canje=timezone.now(),
        fecha_expiracion_cupon=hoy() + timedelta(days=dias_para_vencer),
        estado=estado, codigo=f"MV-{Canje.objects.count():04d}-TEST",
    )
    datos.update(extra)
    return Canje.objects.create(**datos)


def preparar_version_de_reglas():
    VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})


class _ConToken:
    """Usuario con token. Los tests de cada endpoint heredan de aquí."""
    url = ""

    def setUp(self):
        preparar_version_de_reglas()
        self.usuario = crear_usuario()
        token = Token.objects.get(user=self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")


class SinTokenTests(APITestCase):
    def test_todos_los_endpoints_piden_token(self):
        for metodo, url in (
            ("get", "/api/v1/monedas/saldo"),
            ("get", "/api/v1/premios"),
            ("post", "/api/v1/premios/1/canjear"),
            ("get", "/api/v1/cupones"),
        ):
            with self.subTest(url=url):
                self.assertEqual(getattr(self.client, metodo)(url).status_code, 401)


class CatalogoTests(_ConToken, APITestCase):
    url = "/api/v1/premios"

    def get(self):
        r = self.client.get(self.url)
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def test_la_forma_sigue_la_del_mock_de_la_app(self):
        premio = crear_premio(
            foto="assets/img/premios/restaurantes/ookii.webp", fondo="#000000",
            detalle="Detalle", condiciones="Condiciones", vigente_hasta=date(2099, 12, 31),
        )
        self.assertEqual(
            self.get(),
            {
                "categorias": ["Todos", "Restaurantes"],
                "premios": [{
                    "id": str(premio.pk), "nombre": "Ookii", "zona": "Guatemala",
                    "categoria": "Restaurantes", "descripcion": "2x1 en sushi",
                    "detalle": "Detalle", "condiciones": "Condiciones", "costo_monedas": 40,
                    "vence": "2099-12-31", "foto": "assets/img/premios/restaurantes/ookii.webp",
                    "fondo": "#000000", "destacado": False,
                }],
            },
        )

    def test_sin_logo_ni_fecha_va_en_null(self):
        crear_premio()
        premio = self.get()["premios"][0]
        self.assertIsNone(premio["foto"])
        self.assertIsNone(premio["fondo"])
        self.assertIsNone(premio["vence"])

    def test_no_salen_los_apagados_ni_los_vencidos(self):
        crear_premio("Visible")
        crear_premio("Apagado", activo=False)
        crear_premio("Viejo", vigente_hasta=hoy() - timedelta(days=1))
        crear_premio("Ultimo dia", vigente_hasta=hoy())
        self.assertEqual({p["nombre"] for p in self.get()["premios"]}, {"Visible", "Ultimo dia"})

    def test_las_categorias_salen_ordenadas_y_sin_repetir(self):
        crear_premio("A", categoria="Ropa")
        crear_premio("B", categoria="Cafecitos")
        crear_premio("C", categoria="Ropa")
        crear_premio("D", categoria="")
        self.assertEqual(self.get()["categorias"], ["Todos", "Cafecitos", "Ropa"])

    def test_se_ve_completo_sin_poliza(self):
        crear_premio()
        self.assertFalse(PolizaVinculada.objects.filter(usuario=self.usuario).exists())
        self.assertEqual(len(self.get()["premios"]), 1)

    def test_catalogo_vacio(self):
        self.assertEqual(self.get(), {"categorias": ["Todos"], "premios": []})

    def test_sin_perfil_da_403(self):
        sin_perfil = User.objects.create_user(username="sinperfil", password="clave-segura-1")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=sin_perfil).key}")
        self.assertEqual(self.client.get(self.url).status_code, 403)


class SaldoTests(_ConToken, APITestCase):
    url = "/api/v1/monedas/saldo"

    def get(self):
        r = self.client.get(self.url)
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def test_la_forma_sigue_el_contrato(self):
        monedas.acreditar(self.usuario, 25, GANAR)
        datos = self.get()
        season = goals.season_de(hoy())
        self.assertEqual(
            datos,
            {
                "saldo": 25,
                "vence": season.fecha_fin.isoformat(),
                "dias_para_cierre": (season.fecha_fin - hoy()).days,
                "aviso_fin_de_season": (season.fecha_fin - hoy()).days <= 7,
                "puede_canjear": False,
                "season": {
                    "numero": season.numero, "anio": season.anio,
                    "monedas_ganadas": 25, "semanas_completas": 0,
                },
            },
        )

    def test_puede_canjear_solo_con_poliza_verificada(self):
        self.assertFalse(self.get()["puede_canjear"])
        poliza = verificar(self.usuario, PolizaVinculada.EstadoVerificacion.PENDIENTE)
        self.assertFalse(self.get()["puede_canjear"])
        poliza.estado_verificacion = PolizaVinculada.EstadoVerificacion.VERIFICADA
        poliza.save()
        self.assertTrue(self.get()["puede_canjear"])

    def test_lo_gastado_baja_el_saldo_pero_no_lo_ganado_en_la_season(self):
        monedas.acreditar(self.usuario, 50, GANAR)
        monedas.gastar(self.usuario, 20)
        datos = self.get()
        self.assertEqual(datos["saldo"], 30)
        self.assertEqual(datos["season"]["monedas_ganadas"], 50)

    def test_cuenta_las_semanas_completas_y_lo_ganado_solo_de_esta_season(self):
        # Hoy: miércoles 14 oct 2026, season 4 (desde el lunes 28 sep).
        for lunes, cumplido in (
            (date(2026, 9, 21), True),     # season 3: no cuenta
            (date(2026, 9, 28), True),     # cuenta
            (date(2026, 10, 5), False),    # no completó la semana
        ):
            CumplimientoSemanal.objects.create(
                usuario=self.usuario, objetivo_semanal=goals.objetivo_de_la_semana(lunes),
                pasos_semanales=1, workouts_acumulados=1, cumplido=cumplido,
            )
        monedas.acreditar(self.usuario, 7, GANAR, fecha=date(2026, 9, 27))   # season 3
        monedas.acreditar(self.usuario, 10, GANAR, fecha=date(2026, 9, 28))  # season 4
        with mock.patch("Apps.coins.views.hoy", return_value=date(2026, 10, 14)):
            datos = self.get()
        self.assertEqual(datos["season"]["semanas_completas"], 1)
        self.assertEqual(datos["season"]["monedas_ganadas"], 10)
        self.assertEqual(datos["saldo"], 10)   # las 7 de la season 3 ya vencieron

    def test_avisa_7_dias_antes_del_fin_de_la_season(self):
        with mock.patch("Apps.coins.views.hoy", return_value=date(2026, 12, 28)):
            datos = self.get()
        self.assertEqual(datos["dias_para_cierre"], 6)
        self.assertTrue(datos["aviso_fin_de_season"])
        self.assertEqual(datos["vence"], "2027-01-03")

    def test_sin_perfil_da_403(self):
        sin_perfil = User.objects.create_user(username="sinperfil", password="clave-segura-1")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=sin_perfil).key}")
        self.assertEqual(self.client.get(self.url).status_code, 403)


class CanjearTests(_ConToken, APITestCase):
    def setUp(self):
        super().setUp()
        self.premio = crear_premio(costo=40)
        self.url = f"/api/v1/premios/{self.premio.pk}/canjear"

    def _con_poliza_y_monedas(self, cantidad=100):
        verificar(self.usuario)
        monedas.acreditar(self.usuario, cantidad, GANAR)

    def test_canjear_crea_el_cupon_y_descuenta(self):
        self._con_poliza_y_monedas(100)
        r = self.client.post(self.url)
        self.assertEqual(r.status_code, 201, r.content)
        datos = r.json()

        self.assertEqual(datos["saldo"], 60)
        cupon = datos["cupon"]
        self.assertEqual(cupon["comercio"], "Ookii")
        self.assertEqual(cupon["beneficio"], "2x1 en sushi")
        self.assertRegex(cupon["codigo"], r"^MV-[A-Z2-9]{4}-[A-Z2-9]{4}$")
        self.assertEqual(cupon["origen"], "tienda")
        self.assertEqual(cupon["estado"], "activo")
        self.assertEqual(cupon["costo_monedas"], 40)
        self.assertEqual(cupon["canjeado"], hoy().isoformat())
        self.assertEqual(cupon["vence"], (hoy() + timedelta(days=60)).isoformat())
        self.assertEqual(cupon["dias_para_vencer"], 60)
        self.assertIsNone(cupon["usado_el"])

        fila = MonedaLedger.objects.get(usuario=self.usuario, tipo=MonedaLedger.Tipo.CANJE)
        self.assertEqual(fila.cantidad, -40)
        self.assertEqual(Canje.objects.filter(usuario=self.usuario).count(), 1)

    def test_con_el_saldo_justo_alcanza(self):
        self._con_poliza_y_monedas(40)
        self.assertEqual(self.client.post(self.url).json()["saldo"], 0)

    def test_sin_poliza_verificada_da_403_y_no_toca_nada(self):
        monedas.acreditar(self.usuario, 100, GANAR)
        for poliza in (None, PolizaVinculada.EstadoVerificacion.PENDIENTE,
                       PolizaVinculada.EstadoVerificacion.RECHAZADA):
            with self.subTest(poliza=poliza):
                PolizaVinculada.objects.filter(usuario=self.usuario).delete()
                if poliza:
                    verificar(self.usuario, poliza)
                r = self.client.post(self.url)
                self.assertEqual(r.status_code, 403)
                self.assertEqual(r.json()["error"], "poliza_no_verificada")
        self.assertEqual(monedas.saldo(self.usuario), 100)
        self.assertFalse(Canje.objects.exists())

    def test_saldo_insuficiente_da_409_con_el_saldo_y_el_costo(self):
        self._con_poliza_y_monedas(39)
        r = self.client.post(self.url)
        self.assertEqual(r.status_code, 409)
        self.assertEqual(
            (r.json()["error"], r.json()["saldo"], r.json()["costo"]),
            ("saldo_insuficiente", 39, 40),
        )
        self.assertEqual(monedas.saldo(self.usuario), 39)
        self.assertFalse(Canje.objects.exists())

    def test_premio_inexistente_da_404(self):
        self._con_poliza_y_monedas()
        self.assertEqual(self.client.post("/api/v1/premios/99999/canjear").status_code, 404)

    def test_premio_apagado_o_vencido_da_409(self):
        self._con_poliza_y_monedas()
        self.premio.activo = False
        self.premio.save()
        r = self.client.post(self.url)
        self.assertEqual((r.status_code, r.json()["error"]), (409, "premio_no_disponible"))

        self.premio.activo = True
        self.premio.vigente_hasta = hoy() - timedelta(days=1)
        self.premio.save()
        self.assertEqual(self.client.post(self.url).status_code, 409)
        self.assertEqual(monedas.saldo(self.usuario), 100)

    def test_un_premio_gratis_se_canjea_sin_tocar_el_ledger(self):
        verificar(self.usuario)
        gratis = crear_premio("Promo", costo=0)
        r = self.client.post(f"/api/v1/premios/{gratis.pk}/canjear")
        self.assertEqual(r.status_code, 201, r.content)
        self.assertEqual((r.json()["saldo"], r.json()["cupon"]["costo_monedas"]), (0, 0))
        self.assertFalse(MonedaLedger.objects.filter(tipo=MonedaLedger.Tipo.CANJE).exists())

    def test_se_puede_canjear_dos_veces_el_mismo_premio(self):
        self._con_poliza_y_monedas(100)
        self.client.post(self.url)
        self.client.post(self.url)
        codigos = set(Canje.objects.values_list("codigo", flat=True))
        self.assertEqual(len(codigos), 2)
        self.assertEqual(monedas.saldo(self.usuario), 20)

    def test_solo_post(self):
        self.assertEqual(self.client.get(self.url).status_code, 405)

    def test_si_el_codigo_choca_se_reintenta_con_otro(self):
        self._con_poliza_y_monedas(100)
        premios.canjear(self.usuario, self.premio)
        repetido = Canje.objects.get().codigo
        with mock.patch("services.premios._codigo", side_effect=[repetido, "MV-NUEV-OCOD"]):
            canje = premios.canjear(self.usuario, self.premio)
        self.assertEqual(canje.codigo, "MV-NUEV-OCOD")
        # El intento que chocó no dejó ningún descuento suelto.
        self.assertEqual(
            MonedaLedger.objects.filter(tipo=MonedaLedger.Tipo.CANJE).count(), 2,
        )
        self.assertEqual(monedas.saldo(self.usuario), 20)

    def test_un_error_que_no_es_el_codigo_no_se_reintenta(self):
        self._con_poliza_y_monedas(100)
        from django.db import IntegrityError
        with mock.patch("services.premios.Canje.objects.create", side_effect=IntegrityError("otro")):
            with self.assertRaises(IntegrityError):
                premios.canjear(self.usuario, self.premio)
        self.assertEqual(monedas.saldo(self.usuario), 100)   # el descuento se deshizo

    def test_si_no_se_puede_crear_el_cupon_no_se_descuenta(self):
        self._con_poliza_y_monedas(100)
        premios.canjear(self.usuario, self.premio)
        repetido = Canje.objects.get().codigo
        with mock.patch("services.premios._codigo", return_value=repetido):
            with self.assertRaises(RuntimeError):
                premios.canjear(self.usuario, self.premio)
        self.assertEqual(monedas.saldo(self.usuario), 60)  # solo el primer canje
        self.assertEqual(Canje.objects.count(), 1)


class CuponesTests(_ConToken, APITestCase):
    url = "/api/v1/cupones"

    def setUp(self):
        super().setUp()
        self.premio = crear_premio(foto="assets/ookii.webp")

    def get(self):
        r = self.client.get(self.url)
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def test_sin_cupones(self):
        self.assertEqual(self.get(), {"cupones": [], "por_usar": 0})

    def test_la_forma_sigue_la_del_mock_de_la_app(self):
        crear_cupon(self.usuario, self.premio, dias_para_vencer=59, codigo="MV-OK41-7XQ2")
        cupon = self.get()["cupones"][0]
        self.assertEqual(
            cupon,
            {
                "id": str(Canje.objects.get().pk), "comercio": "Ookii", "beneficio": "2x1 en sushi",
                "codigo": "MV-OK41-7XQ2", "origen": "tienda", "canjeado": hoy().isoformat(),
                "vence": (hoy() + timedelta(days=59)).isoformat(), "dias_para_vencer": 59,
                "estado": "activo", "foto": "assets/ookii.webp", "fondo": None,
                "costo_monedas": 40, "ganado_en": None, "usado_el": None,
            },
        )

    def test_activos_primero_y_el_que_vence_antes_arriba(self):
        tarde = crear_cupon(self.usuario, self.premio, dias_para_vencer=50)
        pronto = crear_cupon(self.usuario, self.premio, dias_para_vencer=3)
        usado = crear_cupon(self.usuario, self.premio, estado=Canje.Estado.USADO)
        vencido = crear_cupon(self.usuario, self.premio, dias_para_vencer=-2)
        ids = [c["id"] for c in self.get()["cupones"]]
        self.assertEqual(ids[:2], [str(pronto.pk), str(tarde.pk)])
        self.assertEqual(set(ids[2:]), {str(usado.pk), str(vencido.pk)})

    def test_el_vencido_se_calcula_de_la_fecha(self):
        crear_cupon(self.usuario, self.premio, dias_para_vencer=-1)
        cupon = self.get()["cupones"][0]
        self.assertEqual((cupon["estado"], cupon["dias_para_vencer"]), ("vencido", 0))

    def test_el_ultimo_dia_todavia_esta_activo(self):
        crear_cupon(self.usuario, self.premio, dias_para_vencer=0)
        cupon = self.get()["cupones"][0]
        self.assertEqual((cupon["estado"], cupon["dias_para_vencer"]), ("activo", 0))

    def test_por_usar_cuenta_solo_los_activos(self):
        crear_cupon(self.usuario, self.premio)
        crear_cupon(self.usuario, self.premio, estado=Canje.Estado.USADO)
        crear_cupon(self.usuario, self.premio, dias_para_vencer=-5)
        self.assertEqual(self.get()["por_usar"], 1)

    def test_un_cupon_ganado_no_trae_costo_y_dice_donde_se_gano(self):
        crear_cupon(
            self.usuario, self.premio, origen=Canje.Origen.SEMANA,
            ganado_en="Semana 1", costo_monedas=0,
        )
        cupon = self.get()["cupones"][0]
        self.assertEqual((cupon["origen"], cupon["ganado_en"]), ("semana", "Semana 1"))
        self.assertIsNone(cupon["costo_monedas"])

    def test_un_cupon_usado_trae_la_fecha(self):
        canje = crear_cupon(self.usuario, self.premio)
        premios.marcar_usado(canje)
        cupon = self.get()["cupones"][0]
        self.assertEqual((cupon["estado"], cupon["usado_el"]), ("usado", hoy().isoformat()))

    def test_solo_salen_los_del_usuario(self):
        crear_cupon(crear_usuario("beto"), self.premio)
        self.assertEqual(self.get()["cupones"], [])


class MarcarUsadoTests(TestCase):
    def setUp(self):
        self.usuario = crear_usuario()
        self.premio = crear_premio()

    def test_marca_una_sola_vez(self):
        canje = crear_cupon(self.usuario, self.premio)
        self.assertTrue(premios.marcar_usado(canje))
        canje.refresh_from_db()
        self.assertEqual(canje.estado, Canje.Estado.USADO)
        self.assertIsNotNone(canje.usado_en)
        self.assertFalse(premios.marcar_usado(canje))

    def test_un_cupon_vencido_no_se_puede_marcar(self):
        canje = crear_cupon(self.usuario, self.premio, dias_para_vencer=-1)
        self.assertFalse(premios.marcar_usado(canje))
        canje.refresh_from_db()
        self.assertEqual(canje.estado, Canje.Estado.ACTIVO)


class ImportarPremiosTests(TestCase):
    def _archivo(self, datos):
        carpeta = tempfile.mkdtemp()
        ruta = os.path.join(carpeta, "premios.json")
        with open(ruta, "w", encoding="utf-8") as f:
            json.dump(datos, f)
        return ruta

    def _correr(self, ruta):
        salida = StringIO()
        call_command("importar_premios", ruta, stdout=salida)
        return salida.getvalue()

    def test_carga_y_despues_actualiza_sin_duplicar(self):
        ruta = self._archivo({"premios": [{
            "id": "ookii", "nombre": "Ookii", "zona": "Guatemala", "categoria": "Restaurantes",
            "foto": "assets/ookii.webp", "destacado": True, "descripcion": "2x1",
            "detalle": "d", "condiciones": "c", "costo_monedas": 40, "vence": "2026-12-31",
        }]})
        self.assertIn("1 creados, 0 actualizados", self._correr(ruta))
        premio = Premio.objects.get()
        self.assertEqual(
            (premio.comercio_aliado, premio.costo_monedas, premio.vigente_hasta, premio.fondo),
            ("Ookii", 40, date(2026, 12, 31), ""),
        )

        ruta = self._archivo({"premios": [{
            "nombre": "Ookii", "descripcion": "3x2", "costo_monedas": 55, "fondo": "#000000",
        }]})
        self.assertIn("0 creados, 1 actualizados", self._correr(ruta))
        premio = Premio.objects.get()
        self.assertEqual((premio.descripcion, premio.costo_monedas, premio.fondo), ("3x2", 55, "#000000"))
        self.assertIsNone(premio.vigente_hasta)

    def test_si_un_premio_viene_mal_no_se_guarda_ninguno(self):
        ruta = self._archivo({"premios": [
            {"nombre": "Bueno", "descripcion": "x", "costo_monedas": 10},
            {"nombre": "Sin descripcion", "costo_monedas": 10},
        ]})
        with self.assertRaisesMessage(CommandError, "#2"):
            self._correr(ruta)
        self.assertFalse(Premio.objects.exists())

    def test_costo_y_fecha_invalidos(self):
        for malo in (
            {"nombre": "A", "descripcion": "x", "costo_monedas": -1},
            {"nombre": "A", "descripcion": "x", "costo_monedas": "10"},
            {"nombre": "A", "descripcion": "x", "costo_monedas": 10, "vence": "31/12/2026"},
            "no soy un premio",
        ):
            with self.subTest(malo=malo):
                with self.assertRaises(CommandError):
                    self._correr(self._archivo({"premios": [malo]}))
        self.assertFalse(Premio.objects.exists())

    def test_un_archivo_roto_da_error_claro(self):
        with self.assertRaises(CommandError):
            self._correr(os.path.join(tempfile.mkdtemp(), "no-existe.json"))
        with self.assertRaises(CommandError):
            self._correr(self._archivo({"otra_cosa": []}))


class MigracionCodigosTests(TestCase):
    """La migración 0002 le pone código a los canjes que ya existían."""

    def test_los_canjes_sin_codigo_reciben_uno_unico(self):
        migracion = importlib.import_module("Apps.coins.migrations.0002_premios_y_cupones")
        usuario = crear_usuario()
        premio = crear_premio()
        con_codigo = crear_cupon(usuario, premio, codigo="MV-AAAA-AAAA")
        viejos = [crear_cupon(usuario, premio, codigo=None) for _ in range(3)]

        migracion.codigos_para_los_canjes_viejos(registro_apps, None)

        codigos = [Canje.objects.get(pk=c.pk).codigo for c in viejos]
        for codigo in codigos:
            self.assertRegex(codigo, r"^MV-[A-Z2-9]{4}-[A-Z2-9]{4}$")
        self.assertEqual(len(set(codigos) | {"MV-AAAA-AAAA"}), 4)
        self.assertEqual(Canje.objects.get(pk=con_codigo.pk).codigo, "MV-AAAA-AAAA")
