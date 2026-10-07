"""La Liga y Tus Ligas: tabla, cierre del mes, endpoints (paquete 5, 3 oct 2026)."""
from datetime import date, timedelta
from io import StringIO
from unittest import mock

from django.contrib.auth.models import User
from django.core.management import CommandError, call_command
from django.test import TestCase
from rest_framework.test import APITestCase

from Apps.activities.models import ResumenDiario
from Apps.coins.models import MonedaLedger
from Apps.liga.models import (
    DesgloseLigaMensual,
    LigaAmigos,
    LigaMensual,
    MiembroLigaAmigos,
    PremioPodioLiga,
)
from Apps.poincs.models import Ledger, VersionRegla
from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario
from Apps.users.pruebas import token_de
from services import ligas, monedas

OCTUBRE = date(2026, 10, 1)
FIN_OCTUBRE = date(2026, 10, 31)
NOVIEMBRE = date(2026, 11, 1)
CIERRE = date(2026, 11, 2)     # día 2: octubre ya pasó su margen de gracia
PAGO = date(2026, 11, 9)       # día 9: se paga el podio
HOY = date(2026, 10, 14)

VERIFICADA = PolizaVinculada.EstadoVerificacion.VERIFICADA
PENDIENTE = PolizaVinculada.EstadoVerificacion.PENDIENTE


def version():
    return VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]


def crear_usuario(nombre, poliza=None, nombre_real=None, apellido=None):
    user = User.objects.create_user(username=nombre, password="clave-segura-1")
    usuario = Usuario.objects.create(
        user=user, usuario_id=f"{nombre}-0000-uuid", birth_date=date(1990, 1, 1),
    )
    if poliza:
        PolizaVinculada.objects.create(
            usuario=usuario, policy_number=f"P-{nombre}", insurer="Demo",
            estado_verificacion=poliza, nombre=nombre_real, apellido=apellido,
        )
    return usuario


def puntos(usuario, fecha, cantidad):
    Ledger.objects.create(
        usuario=usuario, puntos=cantidad, tipo=Ledger.TipoLedger.AJUSTE_MANUAL,
        fecha=fecha, version_regla=version(),
    )


def pasos(usuario, fecha, cantidad, workouts=None):
    ResumenDiario.objects.create(
        usuario=usuario, fecha=fecha, pasos_totales_dia=cantidad,
        workouts_cantidad=workouts, puntos_dia=0,
    )


class TablaTests(TestCase):
    def setUp(self):
        self.ana = crear_usuario("ana")
        self.beto = crear_usuario("beto")
        self.carla = crear_usuario("carla")
        self.pks = [self.ana.pk, self.beto.pk, self.carla.pk]

    def _orden(self, hasta=FIN_OCTUBRE):
        return [(f.usuario_pk, f.puntos, f.posicion) for f in ligas.tabla(self.pks, OCTUBRE, hasta)]

    def test_ordena_por_puntos_del_mes(self):
        puntos(self.ana, date(2026, 10, 2), 100)
        puntos(self.beto, date(2026, 10, 2), 300)
        puntos(self.carla, date(2026, 10, 3), 200)
        self.assertEqual(
            self._orden(),
            [(self.beto.pk, 300, 1), (self.carla.pk, 200, 2), (self.ana.pk, 100, 3)],
        )

    def test_a_igualdad_de_puntos_gana_quien_camino_mas(self):
        puntos(self.ana, date(2026, 10, 2), 200)
        puntos(self.beto, date(2026, 10, 2), 200)
        pasos(self.ana, date(2026, 10, 2), 9_000)
        pasos(self.beto, date(2026, 10, 2), 12_000)
        self.assertEqual([f[0] for f in self._orden()][:2], [self.beto.pk, self.ana.pk])

    def test_con_los_mismos_puntos_y_pasos_gana_quien_hizo_mas_workouts(self):
        for u in (self.ana, self.beto):
            puntos(u, date(2026, 10, 2), 200)
            pasos(u, date(2026, 10, 2), 10_000, workouts=1)
        pasos(self.beto, date(2026, 10, 3), 0, workouts=2)       # beto suma 3 workouts, ana 1
        orden = self._orden()
        self.assertEqual([f[0] for f in orden][:2], [self.beto.pk, self.ana.pk])
        self.assertEqual([f[2] for f in orden][:2], [1, 2])

    def test_los_workouts_no_le_ganan_a_los_pasos(self):
        puntos(self.ana, date(2026, 10, 2), 200)
        puntos(self.beto, date(2026, 10, 2), 200)
        pasos(self.ana, date(2026, 10, 2), 12_000, workouts=0)
        pasos(self.beto, date(2026, 10, 2), 9_000, workouts=9)
        self.assertEqual([f[0] for f in self._orden()][:2], [self.ana.pk, self.beto.pk])

    def test_los_workouts_no_le_ganan_a_los_puntos(self):
        puntos(self.ana, date(2026, 10, 2), 300)
        puntos(self.beto, date(2026, 10, 2), 200)
        pasos(self.beto, date(2026, 10, 2), 20_000, workouts=9)
        self.assertEqual(self._orden()[0][0], self.ana.pk)

    def test_un_dia_sin_dato_de_workouts_cuenta_como_cero(self):
        for u in (self.ana, self.beto):
            puntos(u, date(2026, 10, 2), 200)
            pasos(u, date(2026, 10, 2), 10_000)           # workouts_cantidad nulo
        pasos(self.beto, date(2026, 10, 3), 0, workouts=1)
        self.assertEqual(self._orden()[0][0], self.beto.pk)

    def test_empate_total_comparte_el_puesto_y_salta_el_siguiente(self):
        for u in (self.ana, self.beto):
            puntos(u, date(2026, 10, 2), 200)
            pasos(u, date(2026, 10, 2), 10_000, workouts=1)
        puntos(self.carla, date(2026, 10, 2), 50)
        self.assertEqual([f[2] for f in self._orden()], [1, 1, 3])

    def test_solo_cuenta_el_mes_y_hasta_el_dia_pedido(self):
        puntos(self.ana, date(2026, 9, 30), 999)    # septiembre
        puntos(self.ana, date(2026, 10, 1), 10)
        puntos(self.ana, date(2026, 10, 20), 50)    # después del día pedido
        fila = [f for f in ligas.tabla(self.pks, OCTUBRE, HOY) if f.usuario_pk == self.ana.pk][0]
        self.assertEqual(fila.puntos, 10)

    def test_las_correcciones_del_ledger_cuentan(self):
        puntos(self.ana, date(2026, 10, 2), 200)
        puntos(self.ana, date(2026, 10, 2), -150)   # ajuste o retroactivo denegado
        self.assertEqual(dict((f[0], f[1]) for f in self._orden())[self.ana.pk], 50)

    def test_quien_no_tiene_datos_queda_al_final_con_cero(self):
        puntos(self.ana, date(2026, 10, 2), 10)
        self.assertEqual(self._orden()[-1][1], 0)

    def test_tendencia_contra_la_tabla_de_ayer(self):
        puntos(self.ana, date(2026, 10, 13), 100)
        puntos(self.beto, date(2026, 10, 13), 50)
        puntos(self.beto, HOY, 100)                 # hoy pasa a ana
        filas = ligas.tabla(self.pks, OCTUBRE, HOY)
        tendencia = ligas.tendencias(filas, OCTUBRE, HOY)
        self.assertEqual(tendencia[self.beto.pk], ligas.SUBIDA)
        self.assertEqual(tendencia[self.ana.pk], ligas.BAJADA)
        self.assertEqual(tendencia[self.carla.pk], ligas.IGUAL)

    def test_el_dia_1_todos_estan_igual(self):
        puntos(self.ana, OCTUBRE, 100)
        filas = ligas.tabla(self.pks, OCTUBRE, OCTUBRE)
        self.assertEqual(set(ligas.tendencias(filas, OCTUBRE, OCTUBRE).values()), {ligas.IGUAL})

    def test_rango_mes(self):
        self.assertEqual(ligas.rango_mes(date(2026, 2, 14)), (date(2026, 2, 1), date(2026, 2, 28)))
        self.assertEqual(ligas.rango_mes(date(2026, 12, 31)), (date(2026, 12, 1), date(2026, 12, 31)))


class NombrePublicoTests(TestCase):
    def test_con_poliza_verificada_nombre_e_inicial(self):
        u = crear_usuario("ana99", VERIFICADA, "ana maría", "pérez lópez")
        self.assertEqual(ligas.nombre_publico(u), "Ana P.")

    def test_sin_poliza_o_sin_verificar_sale_del_id_publico(self):
        for poliza in (None, PENDIENTE):
            with self.subTest(poliza=poliza):
                u = crear_usuario(f"login-{poliza}", poliza, "Ana", "Pérez")
                nombre = ligas.nombre_publico(u)
                self.assertTrue(nombre.startswith("Usuario "))
                self.assertNotIn("login", nombre)   # nunca el username

    def test_verificada_sin_nombre_de_la_aseguradora(self):
        u = crear_usuario("ana", VERIFICADA)
        self.assertTrue(ligas.nombre_publico(u).startswith("Usuario "))


class CerrarLaLigaTests(TestCase):
    """El mes se cierra el día 2 (tabla final y quién gana qué) y el podio se paga el día 9."""

    def setUp(self):
        version()
        self.oro = crear_usuario("oro", VERIFICADA)
        self.plata = crear_usuario("plata", VERIFICADA)
        self.bronce = crear_usuario("bronce", VERIFICADA)
        self.cuarto = crear_usuario("cuarto", VERIFICADA)
        self.sin_poliza = crear_usuario("libre")
        for usuario, cantidad in (
            (self.oro, 400), (self.plata, 300), (self.bronce, 200), (self.cuarto, 100),
            (self.sin_poliza, 999),
        ):
            puntos(usuario, date(2026, 10, 15), cantidad)

    def saldos(self, hoy):
        return [monedas.saldo(u, hoy) for u in (self.oro, self.plata, self.bronce, self.cuarto)]

    def cerrar_y_pagar(self, mes=OCTUBRE, cierre=CIERRE, pago=PAGO):
        ligas.cerrar_la_liga(mes, cierre)
        return ligas.pagar_la_liga(mes, pago)

    def test_el_podio_viene_cargado_por_la_migracion(self):
        self.assertEqual(ligas.premios_podio(), [30, 20, 10])

    def test_cerrar_guarda_la_tabla_de_todos_y_fija_lo_que_gana_cada_uno_pero_no_paga(self):
        resumen = ligas.cerrar_la_liga(OCTUBRE, CIERRE)
        self.assertEqual(resumen["participantes"], 4)      # el sin póliza no compite
        self.assertEqual(resumen["monedas_por_pagar"], 60)
        self.assertEqual(self.saldos(CIERRE), [0, 0, 0, 0])        # todavía no llegan
        self.assertFalse(MonedaLedger.objects.exists())
        desglose = DesgloseLigaMensual.objects.get(usuario=self.oro)
        self.assertEqual((desglose.posicion_final, desglose.monedas), (1, 30))
        desglose = DesgloseLigaMensual.objects.get(usuario=self.cuarto)
        self.assertEqual((desglose.posicion_final, desglose.puntos_mes, desglose.monedas), (4, 100, 0))
        self.assertEqual(desglose.workouts_acumulados_mes, 0)
        liga = LigaMensual.objects.get(mes=OCTUBRE)
        self.assertEqual((liga.cerrada_en, liga.pagada_en, liga.total_participantes), (CIERRE, None, 4))

    def test_el_dia_9_se_paga_al_podio(self):
        ligas.cerrar_la_liga(OCTUBRE, CIERRE)
        pago = ligas.pagar_la_liga(OCTUBRE, PAGO)
        self.assertEqual((pago["pagada"], pago["monedas_pagadas"]), (True, 60))
        self.assertEqual(self.saldos(PAGO), [30, 20, 10, 0])
        self.assertEqual(monedas.saldo(self.sin_poliza, PAGO), 0)
        self.assertEqual(LigaMensual.objects.get(mes=OCTUBRE).pagada_en, PAGO)

    def test_las_monedas_son_de_liga_y_cuentan_en_la_season_del_pago(self):
        self.cerrar_y_pagar()
        fila = MonedaLedger.objects.get(usuario=self.oro)
        self.assertEqual((fila.tipo, fila.fecha), (MonedaLedger.Tipo.LIGA_MENSUAL, PAGO))

    def test_cerrar_dos_veces_no_duplica(self):
        ligas.cerrar_la_liga(OCTUBRE, CIERRE)
        segunda = ligas.cerrar_la_liga(OCTUBRE, CIERRE)
        self.assertFalse(segunda["cerrada"])
        self.assertEqual(DesgloseLigaMensual.objects.count(), 4)

    def test_pagar_dos_veces_no_paga_dos_veces(self):
        self.cerrar_y_pagar()
        segunda = ligas.pagar_la_liga(OCTUBRE, PAGO)
        self.assertFalse(segunda["pagada"])
        self.assertEqual(self.saldos(PAGO), [30, 20, 10, 0])
        self.assertEqual(MonedaLedger.objects.count(), 3)

    def test_un_mes_que_no_termino_no_se_cierra(self):
        with self.assertRaises(ValueError):
            ligas.cerrar_la_liga(OCTUBRE, FIN_OCTUBRE)

    def test_el_dia_1_es_margen_de_gracia_y_no_se_cierra(self):
        with self.assertRaises(ValueError):
            ligas.cerrar_la_liga(OCTUBRE, NOVIEMBRE)
        self.assertEqual(ligas.ponerse_al_dia(NOVIEMBRE), [])
        self.assertEqual(ligas.dia_de_cierre(OCTUBRE), CIERRE)

    def test_antes_del_dia_9_no_se_paga(self):
        ligas.cerrar_la_liga(OCTUBRE, CIERRE)
        with self.assertRaises(ValueError):
            ligas.pagar_la_liga(OCTUBRE, date(2026, 11, 8))
        self.assertEqual(ligas.pagar_al_dia(date(2026, 11, 8)), [])
        self.assertEqual(ligas.dia_de_pago(OCTUBRE), PAGO)
        self.assertEqual(self.saldos(date(2026, 11, 8)), [0, 0, 0, 0])

    def test_no_se_paga_un_mes_que_no_se_cerro(self):
        with self.assertRaises(ValueError):
            ligas.pagar_la_liga(OCTUBRE, PAGO)

    def test_lo_del_ultimo_dia_que_llega_en_el_margen_cuenta(self):
        # El cuarto caminó el 31 y lo sincronizó el 1: con eso pasa a oro (400 + 1).
        puntos(self.cuarto, FIN_OCTUBRE, 301)
        self.cerrar_y_pagar()
        self.assertEqual(monedas.saldo(self.cuarto, PAGO), 30)

    def test_empate_en_el_podio_comparte_puesto_y_monedas(self):
        puntos(self.plata, date(2026, 10, 16), 100)        # plata empata con oro: 400
        self.cerrar_y_pagar()
        self.assertEqual(self.saldos(PAGO), [30, 30, 10, 0])     # nadie queda 2.º

    def test_el_cierre_desempata_por_pasos_y_despues_por_workouts(self):
        # plata iguala a oro en puntos (400) y en pasos: decide quién hizo más workouts.
        puntos(self.plata, date(2026, 10, 16), 100)
        pasos(self.oro, date(2026, 10, 16), 8_000, workouts=1)
        pasos(self.plata, date(2026, 10, 16), 8_000, workouts=3)
        self.cerrar_y_pagar()
        self.assertEqual([monedas.saldo(u, PAGO) for u in (self.plata, self.oro)], [30, 20])
        desglose = DesgloseLigaMensual.objects.get(usuario=self.plata)
        self.assertEqual((desglose.posicion_final, desglose.workouts_acumulados_mes), (1, 3))

    def test_con_cero_puntos_no_se_gana_aunque_sea_del_podio(self):
        # En noviembre solo oro suma: plata y bronce quedarían 2.º y 3.º con 0.
        puntos(self.oro, date(2026, 11, 5), 10)
        resumen = ligas.cerrar_la_liga(NOVIEMBRE, date(2026, 12, 2))
        self.assertEqual(resumen["monedas_por_pagar"], 30)
        self.assertEqual(
            DesgloseLigaMensual.objects.filter(liga_mensual__mes=NOVIEMBRE, monedas__gt=0).count(), 1,
        )

    def test_usa_los_montos_editados_en_el_admin_antes_del_cierre(self):
        PremioPodioLiga.objects.filter(puesto=1).update(monedas=50)
        self.cerrar_y_pagar()
        self.assertEqual(monedas.saldo(self.oro, PAGO), 50)

    def test_lo_que_se_fijo_al_cerrar_no_cambia_si_se_editan_los_montos_antes_del_pago(self):
        ligas.cerrar_la_liga(OCTUBRE, CIERRE)
        PremioPodioLiga.objects.filter(puesto=1).update(monedas=500)
        ligas.pagar_la_liga(OCTUBRE, PAGO)
        self.assertEqual(monedas.saldo(self.oro, PAGO), 30)

    def test_ponerse_al_dia_no_cierra_meses_anteriores_al_primero(self):
        self.assertEqual(ligas.ponerse_al_dia(date(2026, 10, 20)), [])
        self.assertEqual(ligas.pagar_al_dia(date(2026, 10, 20)), [])
        self.assertFalse(LigaMensual.objects.exists())

    def test_ponerse_al_dia_cierra_los_meses_pendientes_una_sola_vez(self):
        resultados = ligas.ponerse_al_dia(date(2026, 12, 5))
        self.assertEqual([r["mes"] for r in resultados], ["2026-10-01", "2026-11-01"])
        self.assertEqual(ligas.ponerse_al_dia(date(2026, 12, 6)), [])

    def test_pagar_al_dia_paga_los_meses_pendientes_una_sola_vez(self):
        ligas.ponerse_al_dia(date(2026, 12, 5))
        resultados = ligas.pagar_al_dia(date(2026, 12, 10))
        self.assertEqual([r["mes"] for r in resultados], ["2026-10-01", "2026-11-01"])
        self.assertEqual(ligas.pagar_al_dia(date(2026, 12, 11)), [])
        self.assertEqual(monedas.saldo(self.oro, date(2026, 12, 11)), 30)  # noviembre: sin puntos

    def test_pagar_al_dia_cierra_antes_el_mes_que_no_se_cerro(self):
        # El servidor estuvo apagado el día 2 y volvió el 12.
        resultados = ligas.pagar_al_dia(date(2026, 11, 12))
        self.assertEqual([r["mes"] for r in resultados], ["2026-10-01"])
        self.assertEqual(LigaMensual.objects.get(mes=OCTUBRE).cerrada_en, date(2026, 11, 12))
        self.assertEqual(monedas.saldo(self.oro, date(2026, 11, 12)), 30)

    def test_un_mes_ya_cerrado_y_pagado_por_el_modelo_anterior_no_se_paga_otra_vez(self):
        # Meses cerrados antes de este cambio: la migración les puso pagada_en = cerrada_en.
        LigaMensual.objects.create(mes=OCTUBRE, cerrada_en=CIERRE, pagada_en=CIERRE, total_participantes=4)
        self.assertEqual(ligas.pagar_al_dia(PAGO), [])
        self.assertFalse(MonedaLedger.objects.exists())


class _ConToken:
    def setUp(self):
        version()
        self.yo = crear_usuario("yo", VERIFICADA, "Luis", "Montenegro")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(self.yo.user)}")
        reloj = mock.patch("Apps.liga.views.hoy", return_value=HOY)
        reloj.start()
        self.addCleanup(reloj.stop)

    def get(self):
        r = self.client.get("/api/v1/ligas")
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()


class SinTokenTests(APITestCase):
    def test_piden_token(self):
        self.assertEqual(self.client.get("/api/v1/ligas").status_code, 401)
        self.assertEqual(self.client.post("/api/v1/ligas", {"nombre": "x"}).status_code, 401)
        self.assertEqual(self.client.post("/api/v1/ligas/unirse", {"codigo": "x"}).status_code, 401)

    def test_sin_perfil_da_403(self):
        user = User.objects.create_user(username="sinperfil", password="clave-segura-1")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(user)}")
        self.assertEqual(self.client.get("/api/v1/ligas").status_code, 403)


class LaLigaEndpointTests(_ConToken, APITestCase):
    def test_la_forma_sigue_la_de_social_json(self):
        rival = crear_usuario("rival", VERIFICADA, "Ana", "Martínez")
        puntos(self.yo, date(2026, 10, 2), 150)
        puntos(rival, date(2026, 10, 2), 200)
        datos = self.get()
        self.assertTrue(datos["puede_entrar_a_la_liga"])
        self.assertEqual(
            datos["grupos"],
            [{
                "id": "la-liga", "nombre": "La Liga", "tipo": "desconocidos",
                "mostrar_puntos": True, "ciclo": "mes",
                "miembros": [
                    {"nombre": "Ana M.", "puntos_periodo": 200, "posicion": 1,
                     "tendencia": "igual", "es_usuario": False},
                    {"nombre": "Luis M.", "puntos_periodo": 150, "posicion": 2,
                     "tendencia": "igual", "es_usuario": True},
                ],
                "liga": {
                    "arranca": "2026-10-01", "cierra": "2026-10-31",
                    "premios_monedas": [30, 20, 10], "patrocinio": None,
                },
            }],
        )

    def test_nunca_salen_los_pasos_ni_los_workouts(self):
        pasos(self.yo, date(2026, 10, 2), 12_345, workouts=7)
        texto = self.client.get("/api/v1/ligas").content.decode()
        self.assertNotIn("12345", texto)
        self.assertNotIn("pasos", texto)
        self.assertNotIn("workouts", texto)

    def test_sin_poliza_verificada_no_ve_la_liga(self):
        PolizaVinculada.objects.filter(usuario=self.yo).update(estado_verificacion=PENDIENTE)
        self.assertEqual(self.get(), {"puede_entrar_a_la_liga": False, "grupos": []})

    def test_los_que_no_tienen_poliza_no_aparecen_en_la_liga(self):
        crear_usuario("libre")
        nombres = [m["nombre"] for m in self.get()["grupos"][0]["miembros"]]
        self.assertEqual(nombres, ["Luis M."])


class TusLigasEndpointTests(_ConToken, APITestCase):
    def _crear(self, nombre="Oficina"):
        return self.client.post("/api/v1/ligas", {"nombre": nombre}, format="json")

    def test_crear_devuelve_el_grupo_con_su_codigo(self):
        r = self._crear()
        self.assertEqual(r.status_code, 201, r.content)
        grupo = r.json()
        self.assertEqual(
            {k: grupo[k] for k in ("nombre", "tipo", "mostrar_puntos", "ciclo", "creado_por_mi")},
            {"nombre": "Oficina", "tipo": "conocidos", "mostrar_puntos": True, "ciclo": "mes",
             "creado_por_mi": True},
        )
        self.assertRegex(grupo["codigo"], r"^[A-HJ-NP-Z2-9]{6}$")
        self.assertEqual([m["es_usuario"] for m in grupo["miembros"]], [True])
        self.assertEqual(grupo["liga"]["premios_monedas"], [])

    def test_nombre_vacio_o_muy_largo_da_400(self):
        for nombre in ("", "   ", "x" * 61, 123, None, ["Oficina"]):
            with self.subTest(nombre=nombre):
                r = self._crear(nombre)
                self.assertEqual((r.status_code, r.json()["error"]), (400, "nombre_invalido"))
        self.assertFalse(LigaAmigos.objects.exists())

    def test_otro_usuario_se_une_con_el_codigo_sin_poliza(self):
        codigo = self._crear().json()["codigo"]
        amigo = crear_usuario("amigo")                      # sin póliza: Tus Ligas no la exige
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(amigo.user)}")

        r = self.client.post("/api/v1/ligas/unirse", {"codigo": f"  {codigo.lower()} "}, format="json")
        self.assertEqual(r.status_code, 200, r.content)
        self.assertFalse(r.json()["creado_por_mi"])
        self.assertEqual(len(r.json()["miembros"]), 2)

        # Unirse otra vez no duplica.
        self.client.post("/api/v1/ligas/unirse", {"codigo": codigo}, format="json")
        self.assertEqual(MiembroLigaAmigos.objects.filter(usuario=amigo).count(), 1)

        datos = self.get()
        self.assertFalse(datos["puede_entrar_a_la_liga"])
        self.assertEqual([g["nombre"] for g in datos["grupos"]], ["Oficina"])

    def test_codigo_que_no_existe_da_404(self):
        for codigo in ("NOEXIS", "", None, 123456):
            with self.subTest(codigo=codigo):
                r = self.client.post("/api/v1/ligas/unirse", {"codigo": codigo}, format="json")
                self.assertEqual(r.status_code, 404)

    def test_el_get_trae_la_liga_y_despues_tus_ligas(self):
        self._crear("Familia")
        self._crear("Oficina")
        self.assertEqual(
            [g["nombre"] for g in self.get()["grupos"]], ["La Liga", "Familia", "Oficina"],
        )

    def test_la_tabla_de_un_grupo_es_solo_de_sus_miembros(self):
        self._crear()
        crear_usuario("ajeno", VERIFICADA, "Ajeno", "X")
        grupo = self.get()["grupos"][1]
        self.assertEqual([m["nombre"] for m in grupo["miembros"]], ["Luis M."])


class SalirDeUnaLigaTests(_ConToken, APITestCase):
    def _crear(self, nombre="Oficina"):
        return self.client.post("/api/v1/ligas", {"nombre": nombre}, format="json").json()

    def _como(self, usuario):
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token_de(usuario.user)}")

    def _unir(self, usuario, grupo):
        self._como(usuario)
        r = self.client.post("/api/v1/ligas/unirse", {"codigo": grupo["codigo"]}, format="json")
        self.assertEqual(r.status_code, 200, r.content)

    def _salir(self, liga_id):
        return self.client.post(f"/api/v1/ligas/{liga_id}/salir")

    def test_sale_y_el_grupo_deja_de_aparecerle(self):
        grupo = self._crear()
        amigo = crear_usuario("amigo")
        self._unir(amigo, grupo)

        self.assertEqual(self._salir(grupo["id"]).status_code, 204)
        self.assertEqual(self.get()["grupos"], [])
        self.assertFalse(MiembroLigaAmigos.objects.filter(usuario=amigo).exists())

    def test_los_demas_siguen_en_el_grupo_aunque_salga_quien_lo_creo(self):
        grupo = self._crear()
        amigo = crear_usuario("amigo")
        self._unir(amigo, grupo)
        self._como(self.yo)
        self.assertEqual(self._salir(grupo["id"]).status_code, 204)   # sale quien lo creó

        self._como(amigo)
        grupos = self.get()["grupos"]
        self.assertEqual([g["nombre"] for g in grupos], ["Oficina"])
        self.assertEqual([m["es_usuario"] for m in grupos[0]["miembros"]], [True])
        self.assertTrue(LigaAmigos.objects.filter(pk=grupo["id"]).exists())

    def test_el_ultimo_en_salir_borra_el_grupo_y_libera_el_codigo(self):
        grupo = self._crear()
        self.assertEqual(self._salir(grupo["id"]).status_code, 204)
        self.assertFalse(LigaAmigos.objects.exists())
        r = self.client.post("/api/v1/ligas/unirse", {"codigo": grupo["codigo"]}, format="json")
        self.assertEqual(r.status_code, 404)

    def test_se_puede_volver_a_entrar_con_el_codigo(self):
        grupo = self._crear()
        amigo = crear_usuario("amigo")
        self._unir(amigo, grupo)
        self._salir(grupo["id"])
        self._unir(amigo, grupo)
        self.assertEqual(MiembroLigaAmigos.objects.filter(usuario=amigo).count(), 1)

    def test_de_la_liga_no_se_sale(self):
        r = self._salir("la-liga")
        self.assertEqual((r.status_code, r.json()["error"]), (400, "la_liga_no_se_sale"))
        self.assertTrue(self.get()["puede_entrar_a_la_liga"])

    def test_no_se_sale_de_un_grupo_ajeno_ni_inexistente(self):
        grupo = self._crear()
        ajeno = crear_usuario("ajeno")
        self._como(ajeno)
        for liga_id in (grupo["id"], "99999", "abc", "-1", "1.5"):
            with self.subTest(liga_id=liga_id):
                r = self._salir(liga_id)
                self.assertEqual((r.status_code, r.json()["error"]), (404, "no_eres_miembro"))
        self.assertEqual(MiembroLigaAmigos.objects.count(), 1)      # el grupo sigue intacto

    def test_salir_dos_veces_da_404_la_segunda(self):
        grupo = self._crear()
        amigo = crear_usuario("amigo")
        self._unir(amigo, grupo)
        self.assertEqual(self._salir(grupo["id"]).status_code, 204)
        self.assertEqual(self._salir(grupo["id"]).status_code, 404)

    def test_solo_post_y_con_token(self):
        grupo = self._crear()
        self.assertEqual(self.client.get(f"/api/v1/ligas/{grupo['id']}/salir").status_code, 405)
        self.client.credentials()
        self.assertEqual(self._salir(grupo["id"]).status_code, 401)


class ComandoCerrarLigaTests(TestCase):
    def setUp(self):
        version()
        self.oro = crear_usuario("oro", VERIFICADA)
        puntos(self.oro, date(2026, 10, 15), 100)

    def _correr(self, *args, hoy=CIERRE):
        salida = StringIO()
        with mock.patch("Apps.liga.management.commands.cerrar_liga.timezone.localdate", return_value=hoy):
            call_command("cerrar_liga", *args, stdout=salida)
        return salida.getvalue()

    def test_sin_mes_pone_al_dia(self):
        self.assertIn("2026-10-01", self._correr())
        self.assertEqual(monedas.saldo(self.oro, CIERRE), 0)       # cerrado, pero el podio se paga el 9
        self.assertIn("No hay meses", self._correr())

    def test_sin_mes_paga_lo_que_ya_toca(self):
        self._correr()
        salida = self._correr(hoy=PAGO)
        self.assertIn("Podio de La Liga 2026-10-01", salida)
        self.assertEqual(monedas.saldo(self.oro, PAGO), 30)
        self.assertIn("No hay meses", self._correr(hoy=PAGO))

    def test_con_mes_cierra_y_dice_cuando_se_paga(self):
        salida = self._correr("--mes", "2026-10")
        self.assertIn("se paga desde el 2026-11-09", salida)
        self.assertEqual(monedas.saldo(self.oro, CIERRE), 0)
        self.assertIn("ya estaba cerrada", self._correr("--mes", "2026-10"))

    def test_con_mes_el_dia_9_cierra_y_paga_y_otra_vez_no_paga(self):
        self.assertIn("Podio de La Liga 2026-10-01", self._correr("--mes", "2026-10", hoy=PAGO))
        self.assertEqual(monedas.saldo(self.oro, PAGO), 30)
        salida = self._correr("--mes", "2026-10", hoy=PAGO)
        self.assertIn("ya estaba cerrada", salida)
        self.assertIn("ya estaba pagado", salida)
        self.assertEqual(monedas.saldo(self.oro, PAGO), 30)

    def test_errores_claros(self):
        for args, hoy in (
            (("--mes", "octubre"), CIERRE),
            (("--mes", "2026-09"), CIERRE),          # antes de que arranque La Liga
            (("--mes", "2026-10"), FIN_OCTUBRE),        # el mes no terminó
            (("--mes", "2026-10"), NOVIEMBRE),          # margen de gracia
        ):
            with self.subTest(args=args):
                with self.assertRaises(CommandError):
                    self._correr(*args, hoy=hoy)
