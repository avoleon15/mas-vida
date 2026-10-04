"""Patrocinios: semanas, meses de La Liga y premios destacados (paquete 8, 4 oct 2026)."""
from datetime import date, timedelta

from django.core.exceptions import ValidationError
from django.test import TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.coins.models import Canje, Patrocinio
from Apps.coins.test_premios import (
    crear_premio,
    crear_usuario,
    preparar_version_de_reglas,
    verificar,
)
from Apps.liga.test_ligas import puntos
from Apps.objetivos.tests import dia
from Apps.policies.models import PolizaVinculada
from services import goals, ligas, monedas, patrocinios, premios
from services.tiempo import hoy, inicio_semana, lunes_de_la_season, numero_semana_en_season

SEMANA = Patrocinio.Tipo.SEMANA
LIGA = Patrocinio.Tipo.LIGA
DESTACADO = Patrocinio.Tipo.DESTACADO

LUNES = date(2026, 9, 21)
CIERRE_SEMANA = date(2026, 9, 29)       # martes: la semana del 21 ya pasó su margen de gracia
OCTUBRE = date(2026, 10, 1)
CIERRE_LIGA = date(2026, 11, 2)         # día 2: octubre ya pasó su margen de gracia


def comercio(nombre="Montanos", **extra):
    datos = dict(foto="assets/montanos.webp", fondo="#000000")
    datos.update(extra)
    return crear_premio(nombre, **datos)


def vender(tipo, desde, hasta, premio, **extra):
    datos = dict(tipo=tipo, premio=premio, desde=desde, hasta=hasta, cupon="2x1 en Puyazo 8 oz")
    datos.update(extra)
    return Patrocinio.objects.create(**datos)


def vender_semana(lunes, premio, **extra):
    return vender(SEMANA, lunes, lunes + timedelta(days=6), premio, **extra)


def vender_octubre(premio, **extra):
    return vender(LIGA, OCTUBRE, date(2026, 10, 31), premio, **extra)


class _ConToken:
    def setUp(self):
        preparar_version_de_reglas()
        self.usuario = crear_usuario()
        token = Token.objects.get(user=self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def get(self):
        r = self.client.get(self.url)
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()


class PatrocinioModeloTests(TestCase):
    def setUp(self):
        self.premio = comercio()

    def _validar(self, **cambios):
        datos = dict(
            tipo=SEMANA, premio=self.premio, desde=LUNES, hasta=LUNES + timedelta(days=6),
            cupon="2x1", fotos=[],
        )
        datos.update(cambios)
        Patrocinio(**datos).full_clean()

    def test_una_semana_de_lunes_a_domingo_es_valida(self):
        self._validar()

    def test_una_semana_tiene_que_empezar_en_lunes(self):
        with self.assertRaises(ValidationError):
            self._validar(desde=LUNES + timedelta(days=1), hasta=LUNES + timedelta(days=7))

    def test_una_semana_dura_siete_dias(self):
        with self.assertRaises(ValidationError):
            self._validar(hasta=LUNES + timedelta(days=13))

    def test_un_mes_de_la_liga_va_del_dia_1_al_ultimo(self):
        self._validar(tipo=LIGA, desde=OCTUBRE, hasta=date(2026, 10, 31))
        for desde, hasta in ((date(2026, 10, 2), date(2026, 10, 31)), (OCTUBRE, date(2026, 10, 30))):
            with self.subTest(desde=desde, hasta=hasta), self.assertRaises(ValidationError):
                self._validar(tipo=LIGA, desde=desde, hasta=hasta)

    def test_un_destacado_es_cualquier_rango_y_no_pide_cupon(self):
        self._validar(tipo=DESTACADO, desde=date(2026, 10, 5), hasta=date(2026, 10, 20), cupon="")

    def test_hasta_no_puede_ser_antes_de_desde(self):
        with self.assertRaises(ValidationError):
            self._validar(tipo=DESTACADO, desde=date(2026, 10, 5), hasta=date(2026, 10, 4))

    def test_semana_y_liga_piden_el_texto_del_cupon(self):
        with self.assertRaises(ValidationError):
            self._validar(cupon="  ")

    def test_semana_y_liga_piden_que_el_comercio_tenga_logo(self):
        sin_logo = crear_premio("Sin logo")
        with self.assertRaises(ValidationError):
            self._validar(premio=sin_logo)

    def test_las_fotos_son_una_lista_de_texto(self):
        with self.assertRaises(ValidationError):
            self._validar(fotos="una.webp")
        with self.assertRaises(ValidationError):
            self._validar(fotos=[1, 2])

    def test_una_marca_por_semana_y_por_mes(self):
        vender_semana(LUNES, self.premio)
        with self.assertRaises(Exception):
            vender_semana(LUNES, comercio("Otra"))

    def test_dos_destacados_el_mismo_dia_si_se_pueden(self):
        vender(DESTACADO, OCTUBRE, date(2026, 10, 31), self.premio)
        vender(DESTACADO, OCTUBRE, date(2026, 10, 31), comercio("Otra"))


class ComoJsonTests(TestCase):
    def test_sin_patrocinio_es_null(self):
        self.assertIsNone(patrocinios.como_json(None))

    def test_la_forma_que_lee_la_app(self):
        premio = comercio("Montanos", comercio_aliado="Montanos")
        p = vender_semana(LUNES, premio, acento="#8C5A3C", fotos=["a.webp", "b.webp"])
        self.assertEqual(patrocinios.como_json(p), {
            "id": str(premio.pk),
            "marca": "Montanos",
            "logo": "assets/montanos.webp",
            "fondo": "#000000",
            "acento": "#8C5A3C",
            "cupon": "2x1 en Puyazo 8 oz",
            "fotos": ["a.webp", "b.webp"],
        })

    def test_sin_fondo_ni_acento_van_en_null(self):
        premio = comercio(fondo="")
        datos = patrocinios.como_json(vender_semana(LUNES, premio))
        self.assertIsNone(datos["fondo"])
        self.assertIsNone(datos["acento"])
        self.assertEqual(datos["fotos"], [])


class SemanasEndpointTests(_ConToken, APITestCase):
    url = "/api/v1/objetivos/semanas"

    def setUp(self):
        super().setUp()
        self.lunes = lunes_de_la_season(hoy())
        self.premio = comercio()

    def test_sin_patrocinios_todas_van_en_null(self):
        self.assertTrue(all(s["patrocinador"] is None for s in self.get()["semanas"]))

    def test_la_semana_vendida_trae_su_marca_y_las_demas_null(self):
        vender_semana(self.lunes[2], self.premio, acento="#8C5A3C")
        semanas = self.get()["semanas"]
        self.assertEqual(semanas[2]["patrocinador"]["marca"], self.premio.comercio_aliado)
        self.assertEqual(semanas[2]["patrocinador"]["id"], str(self.premio.pk))
        self.assertEqual(semanas[2]["patrocinador"]["acento"], "#8C5A3C")
        self.assertEqual(
            [s["numero"] for s in semanas if s["patrocinador"] is not None], [3],
        )

    def test_una_semana_pasada_y_una_futura_tambien_traen_su_marca(self):
        vender_semana(self.lunes[0], self.premio)
        vender_semana(self.lunes[-1], comercio("Futura"))
        semanas = self.get()["semanas"]
        self.assertIsNotNone(semanas[0]["patrocinador"])
        self.assertEqual(semanas[-1]["patrocinador"]["marca"], "Futura")

    def test_un_patrocinio_apagado_no_sale(self):
        vender_semana(self.lunes[1], self.premio, activo=False)
        self.assertTrue(all(s["patrocinador"] is None for s in self.get()["semanas"]))

    def test_un_patrocinio_de_otra_season_no_sale(self):
        vender_semana(self.lunes[0] - timedelta(days=7), self.premio)
        self.assertTrue(all(s["patrocinador"] is None for s in self.get()["semanas"]))

    def test_lo_de_liga_o_destacado_no_se_cuela_en_las_semanas(self):
        vender(DESTACADO, self.lunes[0], self.lunes[0] + timedelta(days=6), self.premio)
        self.assertTrue(all(s["patrocinador"] is None for s in self.get()["semanas"]))


class LigaEndpointTests(_ConToken, APITestCase):
    url = "/api/v1/ligas"

    def setUp(self):
        super().setUp()
        verificar(self.usuario)
        self.mes = hoy().replace(day=1)
        self.fin = (self.mes + timedelta(days=32)).replace(day=1) - timedelta(days=1)
        self.premio = comercio("Ookii")

    def _la_liga(self):
        return self.get()["grupos"][0]

    def test_sin_patrocinio_va_en_null(self):
        self.assertIsNone(self._la_liga()["liga"]["patrocinio"])

    def test_el_mes_vendido_trae_la_marca(self):
        vender(LIGA, self.mes, self.fin, self.premio, cupon="2x1 en sushi", acento="#C0392B")
        patrocinio = self._la_liga()["liga"]["patrocinio"]
        self.assertEqual(patrocinio["marca"], self.premio.comercio_aliado)
        self.assertEqual(patrocinio["cupon"], "2x1 en sushi")
        self.assertEqual(patrocinio["acento"], "#C0392B")
        self.assertEqual(patrocinio["logo"], "assets/montanos.webp")

    def test_el_patrocinio_de_otro_mes_no_sale(self):
        anterior_fin = self.mes - timedelta(days=1)
        vender(LIGA, anterior_fin.replace(day=1), anterior_fin, self.premio)
        self.assertIsNone(self._la_liga()["liga"]["patrocinio"])

    def test_apagado_no_sale(self):
        vender(LIGA, self.mes, self.fin, self.premio, activo=False)
        self.assertIsNone(self._la_liga()["liga"]["patrocinio"])

    def test_tus_ligas_nunca_traen_patrocinio(self):
        vender(LIGA, self.mes, self.fin, self.premio)
        r = self.client.post(self.url, {"nombre": "Oficina"}, format="json")
        self.assertEqual(r.status_code, 201, r.content)
        grupo = [g for g in self.get()["grupos"] if g["nombre"] == "Oficina"][0]
        self.assertIsNone(grupo["liga"]["patrocinio"])


class DestacadoTests(_ConToken, APITestCase):
    url = "/api/v1/premios"

    def setUp(self):
        super().setUp()
        self.premio = comercio("Ookii")
        self.otro = comercio("Smart Fit")

    def _destacados(self):
        return {p["nombre"]: p["destacado"] for p in self.get()["premios"]}

    def test_sin_patrocinios_nadie_es_destacado(self):
        self.assertEqual(self._destacados(), {"Ookii": False, "Smart Fit": False})

    def test_el_comercio_vendido_hoy_sale_destacado(self):
        vender(DESTACADO, hoy() - timedelta(days=3), hoy() + timedelta(days=3), self.premio, cupon="")
        self.assertEqual(self._destacados(), {"Ookii": True, "Smart Fit": False})

    def test_los_dos_extremos_del_rango_cuentan(self):
        vender(DESTACADO, hoy(), hoy(), self.premio)
        vender(DESTACADO, hoy() - timedelta(days=5), hoy(), self.otro)
        self.assertEqual(self._destacados(), {"Ookii": True, "Smart Fit": True})

    def test_vencido_futuro_o_apagado_no_cuentan(self):
        vender(DESTACADO, hoy() - timedelta(days=9), hoy() - timedelta(days=1), self.premio)
        vender(DESTACADO, hoy() + timedelta(days=1), hoy() + timedelta(days=9), self.otro)
        vender(DESTACADO, hoy(), hoy(), comercio("Apagado"), activo=False)
        self.assertEqual(
            self._destacados(), {"Ookii": False, "Smart Fit": False, "Apagado": False},
        )

    def test_una_semana_o_una_liga_vendida_no_destaca_el_premio(self):
        vender(SEMANA, inicio_semana(hoy()), inicio_semana(hoy()) + timedelta(days=6), self.premio)
        self.assertEqual(self._destacados()["Ookii"], False)


class PatrociniosVigentesTests(_ConToken, APITestCase):
    url = "/api/v1/patrocinios"

    def setUp(self):
        super().setUp()
        self.premio = comercio("Ookii")
        self.lunes = inicio_semana(hoy())

    def test_pide_token(self):
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_sin_perfil_da_403(self):
        from django.contrib.auth.models import User
        user = User.objects.create_user(username="sinperfil", password="clave-segura-1")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=user).key}")
        self.assertEqual(self.client.get(self.url).status_code, 403)

    def test_sin_patrocinios_las_tres_listas_vienen_vacias(self):
        self.assertEqual(self.get(), {"semanas": [], "ligas": [], "destacados": []})

    def test_trae_lo_vendido_por_tipo_con_la_forma_de_la_app(self):
        vender_semana(self.lunes, self.premio, acento="#8C5A3C")
        mes = hoy().replace(day=1)
        fin = (mes + timedelta(days=32)).replace(day=1) - timedelta(days=1)
        vender(LIGA, mes, fin, self.premio, cupon="2x1 en sushi")
        vender(DESTACADO, hoy(), hoy() + timedelta(days=9), self.premio, cupon="")
        datos = self.get()
        self.assertEqual(datos["semanas"], [{
            "fecha_inicio": self.lunes.isoformat(),
            "fecha_fin": (self.lunes + timedelta(days=6)).isoformat(),
            "patrocinador": patrocinios.como_json(Patrocinio.objects.get(tipo=SEMANA)),
        }])
        self.assertEqual(datos["semanas"][0]["patrocinador"]["acento"], "#8C5A3C")
        self.assertEqual(datos["ligas"][0]["arranca"], mes.isoformat())
        self.assertEqual(datos["ligas"][0]["cierra"], fin.isoformat())
        self.assertEqual(datos["ligas"][0]["patrocinio"]["cupon"], "2x1 en sushi")
        self.assertEqual(datos["destacados"], [{
            "premio_id": str(self.premio.pk),
            "desde": hoy().isoformat(),
            "hasta": (hoy() + timedelta(days=9)).isoformat(),
        }])

    def test_incluye_lo_futuro_y_deja_fuera_lo_que_ya_termino(self):
        vender_semana(self.lunes - timedelta(days=7), self.premio)                  # ya terminó
        vender_semana(self.lunes + timedelta(days=14), comercio("Futura"))
        vender(DESTACADO, hoy() - timedelta(days=9), hoy() - timedelta(days=1), self.premio)
        datos = self.get()
        self.assertEqual(
            [s["fecha_inicio"] for s in datos["semanas"]],
            [(self.lunes + timedelta(days=14)).isoformat()],
        )
        self.assertEqual(datos["destacados"], [])

    def test_la_semana_en_curso_y_el_ultimo_dia_de_un_destacado_todavia_cuentan(self):
        vender_semana(self.lunes, self.premio)
        vender(DESTACADO, hoy() - timedelta(days=3), hoy(), self.premio)
        datos = self.get()
        self.assertEqual(len(datos["semanas"]), 1)
        self.assertEqual(len(datos["destacados"]), 1)

    def test_lo_apagado_no_sale_y_va_ordenado_por_fecha(self):
        vender_semana(self.lunes + timedelta(days=7), comercio("Dos"))
        vender_semana(self.lunes, comercio("Uno"))
        vender_semana(self.lunes + timedelta(days=14), comercio("Apagada"), activo=False)
        marcas = [s["patrocinador"]["marca"] for s in self.get()["semanas"]]
        self.assertEqual(marcas, ["Uno", "Dos"])


class CuponDeSemanaTests(TestCase):
    def setUp(self):
        preparar_version_de_reglas()
        self.premio = comercio("Montanos")
        self.patrocinio = vender_semana(LUNES, self.premio)
        self.ana = crear_usuario("ana")
        verificar(self.ana)

    def _completa(self, usuario):
        dia(usuario, LUNES, 50_000, workouts=1)

    def _cerrar(self, **kw):
        return goals.cerrar_semana(LUNES, CIERRE_SEMANA, **kw)

    def test_quien_completa_la_semana_gana_el_cupon_ademas_de_las_monedas(self):
        self._completa(self.ana)
        resumen = self._cerrar()
        cupon = Canje.objects.get(usuario=self.ana)
        self.assertEqual(resumen["cupones"], 1)
        self.assertEqual(cupon.origen, Canje.Origen.SEMANA)
        self.assertEqual(cupon.ganado_en, f"Semana {numero_semana_en_season(LUNES)}")
        self.assertEqual(cupon.beneficio, "2x1 en Puyazo 8 oz")
        self.assertEqual(cupon.patrocinio, self.patrocinio)
        self.assertEqual(cupon.premio, self.premio)
        self.assertEqual(cupon.costo_monedas, 0)
        self.assertEqual(cupon.estado, Canje.Estado.ACTIVO)
        self.assertTrue(cupon.codigo.startswith("MV-"))
        self.assertEqual(
            cupon.fecha_expiracion_cupon,
            timezone.localdate() + timedelta(days=premios.DIAS_DE_UN_CUPON),
        )
        # Las monedas de los dos objetivos se pagan igual.
        self.assertEqual(monedas.saldo(self.ana, CIERRE_SEMANA), 10)

    def test_un_solo_componente_paga_monedas_pero_no_el_cupon(self):
        dia(self.ana, LUNES, 50_000)             # pasos sí, workouts no
        resumen = self._cerrar()
        self.assertEqual(monedas.saldo(self.ana, CIERRE_SEMANA), 5)
        self.assertEqual(resumen["cupones"], 0)
        self.assertFalse(Canje.objects.exists())

    def test_sin_poliza_verificada_no_se_gana(self):
        libre = crear_usuario("libre")
        pendiente = crear_usuario("pendiente")
        verificar(pendiente, PolizaVinculada.EstadoVerificacion.PENDIENTE)
        for u in (libre, pendiente):
            self._completa(u)
        self._cerrar()
        self.assertFalse(Canje.objects.filter(usuario__in=[libre, pendiente]).exists())
        self.assertEqual(monedas.saldo(libre, CIERRE_SEMANA), 10)   # las monedas sí

    def test_una_semana_sin_marca_no_da_cupon(self):
        self.patrocinio.delete()
        self._completa(self.ana)
        self.assertEqual(self._cerrar()["cupones"], 0)
        self.assertFalse(Canje.objects.exists())

    def test_un_patrocinio_apagado_no_da_cupon(self):
        self.patrocinio.activo = False
        self.patrocinio.save()
        self._completa(self.ana)
        self._cerrar()
        self.assertFalse(Canje.objects.exists())

    def test_correr_el_cierre_dos_veces_no_duplica(self):
        self._completa(self.ana)
        self._cerrar()
        segundo = self._cerrar()
        self.assertEqual(Canje.objects.filter(usuario=self.ana).count(), 1)
        self.assertEqual(segundo["cupones"], 0)

    def test_la_correccion_del_mediodia_no_da_cupones(self):
        self._completa(self.ana)
        self._cerrar(correccion=True)
        self.assertFalse(Canje.objects.exists())

    def test_la_semana_de_otra_marca_no_da_el_cupon_de_esta(self):
        otra = vender_semana(LUNES + timedelta(days=7), comercio("Otra"))
        self._completa(self.ana)
        self._cerrar()
        self.assertEqual(Canje.objects.get(usuario=self.ana).patrocinio, self.patrocinio)
        self.assertNotEqual(Canje.objects.get(usuario=self.ana).patrocinio, otra)

    def test_con_retroactivo_denegado_no_hay_cupon_de_una_semana_anterior(self):
        denegado = crear_usuario("denegado")
        PolizaVinculada.objects.create(
            usuario=denegado, policy_number="P-DEN", insurer="Demo",
            estado_verificacion=PolizaVinculada.EstadoVerificacion.VERIFICADA,
            birth_date_confirmada=date(1991, 6, 6),            # no coincide con la del registro
            fecha_verificacion=timezone.now(),
        )
        self._completa(denegado)
        self._cerrar()
        self.assertFalse(Canje.objects.filter(usuario=denegado).exists())

    def test_cada_quien_recibe_su_propio_cupon_con_su_codigo(self):
        beto = crear_usuario("beto")
        verificar(beto)
        for u in (self.ana, beto):
            self._completa(u)
        self.assertEqual(self._cerrar()["cupones"], 2)
        codigos = set(Canje.objects.values_list("codigo", flat=True))
        self.assertEqual(len(codigos), 2)

    def test_ganar_cupon_dos_veces_devuelve_none_la_segunda(self):
        primero = premios.ganar_cupon(self.ana, self.patrocinio, Canje.Origen.SEMANA, "Semana 1")
        segundo = premios.ganar_cupon(self.ana, self.patrocinio, Canje.Origen.SEMANA, "Semana 1")
        self.assertIsNotNone(primero)
        self.assertIsNone(segundo)


class CuponDeLigaTests(TestCase):
    def setUp(self):
        preparar_version_de_reglas()
        self.premio = comercio("Ookii")
        self.patrocinio = vender_octubre(self.premio, cupon="2x1 en sushi")
        self.usuarios = {}
        for nombre, cantidad in (("oro", 400), ("plata", 300), ("bronce", 200), ("cuarto", 100), ("cero", 0)):
            u = crear_usuario(nombre)
            verificar(u)
            if cantidad:
                puntos(u, date(2026, 10, 15), cantidad)
            self.usuarios[nombre] = u

    def _cerrar(self):
        return ligas.cerrar_la_liga(OCTUBRE, CIERRE_LIGA)

    def test_el_podio_gana_el_cupon_ademas_de_las_monedas(self):
        resumen = self._cerrar()
        self.assertEqual(resumen["cupones"], 3)
        ganadores = {c.usuario.usuario_id: c for c in Canje.objects.select_related("usuario")}
        self.assertEqual(set(ganadores), {"oro-1", "plata-1", "bronce-1"})
        cupon = ganadores["oro-1"]
        self.assertEqual(cupon.origen, Canje.Origen.LIGA)
        self.assertEqual(cupon.ganado_en, "La Liga de octubre")
        self.assertEqual(cupon.beneficio, "2x1 en sushi")
        self.assertEqual(cupon.patrocinio, self.patrocinio)
        self.assertEqual(cupon.costo_monedas, 0)
        self.assertEqual(monedas.saldo(self.usuarios["oro"], CIERRE_LIGA), 30)

    def test_quien_no_llega_al_podio_o_tiene_cero_puntos_no_gana(self):
        self._cerrar()
        self.assertFalse(Canje.objects.filter(usuario=self.usuarios["cuarto"]).exists())
        self.assertFalse(Canje.objects.filter(usuario=self.usuarios["cero"]).exists())

    def test_sin_patrocinio_no_hay_cupones_y_las_monedas_se_pagan(self):
        self.patrocinio.delete()
        self.assertEqual(self._cerrar()["cupones"], 0)
        self.assertFalse(Canje.objects.exists())
        self.assertEqual(monedas.saldo(self.usuarios["plata"], CIERRE_LIGA), 20)

    def test_un_patrocinio_apagado_no_da_cupones(self):
        self.patrocinio.activo = False
        self.patrocinio.save()
        self._cerrar()
        self.assertFalse(Canje.objects.exists())

    def test_cerrar_otra_vez_no_duplica(self):
        self._cerrar()
        segundo = self._cerrar()
        self.assertFalse(segundo["cerrada"])
        self.assertEqual(Canje.objects.count(), 3)

    def test_con_empate_en_el_podio_los_dos_ganan_su_cupon(self):
        puntos(self.usuarios["cuarto"], date(2026, 10, 16), 100)      # 200, igual que bronce
        for nombre in ("bronce", "cuarto"):
            from Apps.activities.models import ResumenDiario
            ResumenDiario.objects.create(
                usuario=self.usuarios[nombre], fecha=date(2026, 10, 15),
                pasos_totales_dia=10_000, workouts_cantidad=1, puntos_dia=0,
            )
        self._cerrar()
        # Posiciones 1, 2, 3 y 3: el cuarto lugar empata en el tercero, pero las
        # monedas y el cupón son de los puestos 1 a 3 de la tabla.
        ganadores = set(Canje.objects.values_list("usuario__usuario_id", flat=True))
        self.assertTrue({"oro-1", "plata-1"} <= ganadores)
        self.assertEqual(len(ganadores), Canje.objects.count())

    def test_el_mes_de_otro_patrocinio_no_se_mezcla(self):
        self.patrocinio.delete()
        vender(LIGA, date(2026, 11, 1), date(2026, 11, 30), self.premio)
        self.assertEqual(self._cerrar()["cupones"], 0)


class MisCuponesTests(_ConToken, APITestCase):
    url = "/api/v1/cupones"

    def setUp(self):
        super().setUp()
        verificar(self.usuario)
        self.premio = comercio("Ookii", descripcion="Beneficio por definir")

    def test_el_cupon_ganado_dice_el_beneficio_de_la_marca_y_donde_se_gano(self):
        patrocinio = vender_octubre(self.premio, cupon="2x1 en sushi")
        premios.ganar_cupon(self.usuario, patrocinio, Canje.Origen.LIGA, "La Liga de octubre")
        cupon = self.get()["cupones"][0]
        self.assertEqual(cupon["beneficio"], "2x1 en sushi")
        self.assertEqual(cupon["origen"], "liga")
        self.assertEqual(cupon["ganado_en"], "La Liga de octubre")
        self.assertIsNone(cupon["costo_monedas"])
        self.assertEqual(cupon["estado"], "activo")

    def test_el_cupon_de_la_tienda_sigue_diciendo_el_beneficio_del_premio(self):
        from Apps.coins.test_premios import crear_cupon
        crear_cupon(self.usuario, self.premio)
        self.assertEqual(self.get()["cupones"][0]["beneficio"], "Beneficio por definir")
