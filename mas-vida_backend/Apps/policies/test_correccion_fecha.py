"""Si la aseguradora corrige la fecha después de verificar, no se le quita nada a la persona (etapa 11, 5 oct 2026)."""
from datetime import date, datetime, timedelta
from decimal import Decimal
from importlib import import_module
from zoneinfo import ZoneInfo

from django.apps import apps
from django.contrib.admin.sites import site
from django.contrib.auth import get_user_model
from django.contrib.messages.storage.fallback import FallbackStorage
from django.test import RequestFactory, TestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient, APITestCase

from Apps.activities.models import ResumenDiario
from Apps.objetivos.models import MetaPasosPorEdad
from Apps.poincs.models import Ledger, VersionRegla
from Apps.policies.admin import PolizaVinculadaAdmin
from Apps.policies.models import CorreccionDeNacimiento, PolizaVinculada, RegistroAseguradora
from Apps.users.models import Usuario
from services import goals, perfil, polizas
from services.daily_scoring import fecha_nacimiento_efectiva
from services.tiempo import inicio_semana

User = get_user_model()
GT = ZoneInfo("America/Guatemala")
VERIFICADA = PolizaVinculada.EstadoVerificacion.VERIFICADA
PENDIENTE = PolizaVinculada.EstadoVerificacion.PENDIENTE
RETRO = PolizaVinculada.Retroactivo

HOY = timezone.localdate()
A_LOS_60 = date(HOY.year - 60, 1, 1)         # 60 años cumplidos cualquier día de este año
A_LOS_59 = date(HOY.year - 59, 1, 1)         # 59
REAL = date(1990, 5, 17)


def version():
    return VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})[0]


def crear_usuario(nombre="ana", declarada=REAL):
    user = User.objects.create_user(f"{nombre}@correo.com", password="Clave-segura-2026")
    return Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=declarada)


def poliza_de(usuario, confirmada=REAL, estado=VERIFICADA, retroactivo="", corte=None, numero=None):
    return PolizaVinculada.objects.create(
        usuario=usuario, policy_number=numero or f"P-{usuario.pk}", insurer="Demo",
        estado_verificacion=estado, birth_date_confirmada=confirmada,
        fecha_verificacion=timezone.now() if estado == VERIFICADA else None,
        retroactivo=retroactivo, corte_retroactivo=corte,
    )


def corregir(poliza, fecha_nueva, desde=None):
    """Lo que hace el admin al cambiar la fecha de una póliza ya verificada."""
    CorreccionDeNacimiento.objects.create(
        poliza=poliza, fecha_anterior=poliza.birth_date_confirmada, fecha_nueva=fecha_nueva,
        desde=desde or timezone.localdate(),
    )
    PolizaVinculada.objects.filter(pk=poliza.pk).update(birth_date_confirmada=fecha_nueva)
    poliza.refresh_from_db()


class VeredictoSeCongelaAlVerificarTests(TestCase):
    def setUp(self):
        version()

    def pendiente(self, usuario, confirmada):
        return PolizaVinculada.objects.create(
            usuario=usuario, policy_number=f"P-{usuario.pk}", insurer="Demo",
            estado_verificacion=PENDIENTE, birth_date_confirmada=confirmada,
        )

    def test_fecha_igual_queda_aplicado_sin_corte(self):
        poliza = self.pendiente(crear_usuario(declarada=REAL), REAL)
        polizas.verificar(poliza)
        poliza.refresh_from_db()
        self.assertEqual((poliza.retroactivo, poliza.corte_retroactivo), (RETRO.APLICADO, None))

    def test_un_error_tolerado_queda_tolerado_sin_corte(self):
        poliza = self.pendiente(crear_usuario(declarada=date(1991, 5, 17)), REAL)
        polizas.verificar(poliza)
        poliza.refresh_from_db()
        self.assertEqual((poliza.retroactivo, poliza.corte_retroactivo), (RETRO.TOLERADO, None))

    def test_una_mentira_queda_denegada_con_corte_el_dia_de_la_verificacion(self):
        poliza = self.pendiente(crear_usuario(declarada=date(1988, 5, 17)), REAL)
        ahora = datetime(2026, 9, 24, 20, 0, tzinfo=GT)
        polizas.verificar(poliza, ahora=ahora)
        poliza.refresh_from_db()
        self.assertEqual((poliza.retroactivo, poliza.corte_retroactivo), (RETRO.DENEGADO, date(2026, 9, 24)))

    def test_rechazar_borra_el_veredicto(self):
        poliza = self.pendiente(crear_usuario(), REAL)
        poliza.retroactivo, poliza.corte_retroactivo = RETRO.DENEGADO, HOY
        poliza.save()
        polizas.rechazar(poliza)
        poliza.refresh_from_db()
        self.assertEqual((poliza.retroactivo, poliza.corte_retroactivo), ("", None))

    def test_volver_a_vincular_una_rechazada_empieza_sin_veredicto(self):
        usuario = crear_usuario()
        poliza = poliza_de(usuario, estado=PENDIENTE)
        poliza.estado_verificacion, poliza.retroactivo, poliza.corte_retroactivo = "rechazada", RETRO.DENEGADO, HOY
        poliza.save()
        nueva = polizas.vincular(usuario, "P-NUEVA", "Demo", date(2026, 1, 1))
        self.assertEqual((nueva.retroactivo, nueva.corte_retroactivo), ("", None))

    def test_si_la_carrera_se_pierde_no_queda_veredicto_ni_verificada_en_memoria(self):
        otra = crear_usuario("otra")
        poliza_de(otra, numero="P-X")
        ana = crear_usuario("ana")
        pendiente = PolizaVinculada.objects.create(
            usuario=ana, policy_number="P-X", insurer="Demo", estado_verificacion=PENDIENTE, birth_date_confirmada=REAL,
        )
        with self.assertRaises(polizas.PolizaEnOtraCuenta):
            polizas.verificar(pendiente)
        self.assertEqual((pendiente.retroactivo, pendiente.estado_verificacion), ("", PENDIENTE))


class UnaCorreccionNoCambiaElVeredictoTests(TestCase):
    def setUp(self):
        self.version = version()

    def historial(self, usuario):
        for dias in (3, 2, 1):
            Ledger.objects.create(
                usuario=usuario, fecha=HOY - timedelta(days=dias), tipo=Ledger.TipoLedger.PASOS, puntos=50,
                version_regla=self.version,
            )

    def total(self, usuario):
        return sum(Ledger.objects.filter(usuario=usuario).values_list("puntos", flat=True))

    def test_quien_tenia_la_fecha_bien_no_se_vuelve_mentiroso_si_la_aseguradora_cambia_su_fecha(self):
        # La aseguradora se había equivocado: la fecha real es 10 años distinta. Antes esto habría
        # convertido a la persona en "mentirosa" y anulado todo su historial.
        ana = crear_usuario(declarada=REAL)
        poliza = poliza_de(ana, REAL, retroactivo=RETRO.APLICADO)
        self.historial(ana)
        corregir(poliza, date(1980, 5, 17))
        self.assertIsNone(polizas.fecha_corte_sin_retroactivo(ana))
        self.assertEqual(polizas.cortes_de_retroactivo([ana.pk]), {})
        self.assertEqual(self.total(ana), 150)

    def test_quien_fue_denegado_sigue_denegado_aunque_la_fecha_corregida_coincida(self):
        ana = crear_usuario(declarada=date(1988, 5, 17))
        poliza = poliza_de(ana, REAL, retroactivo=RETRO.DENEGADO, corte=date(2026, 9, 24))
        corregir(poliza, date(1988, 5, 17))              # ahora coincide con la del registro
        self.assertEqual(polizas.fecha_corte_sin_retroactivo(ana), date(2026, 9, 24))

    def test_quien_fue_tolerado_sigue_tolerado(self):
        ana = crear_usuario(declarada=date(1991, 5, 17))
        poliza = poliza_de(ana, REAL, retroactivo=RETRO.TOLERADO)
        corregir(poliza, date(1970, 1, 1))
        self.assertIsNone(polizas.fecha_corte_sin_retroactivo(ana))

    def test_la_semana_de_quien_se_corrigio_sigue_contando_entera(self):
        ana = crear_usuario(declarada=REAL)
        poliza = poliza_de(ana, REAL, retroactivo=RETRO.APLICADO)
        lunes = inicio_semana(HOY) - timedelta(days=7)
        for n in range(7):
            ResumenDiario.objects.create(
                usuario=ana, fecha=lunes + timedelta(days=n), pasos_totales_dia=10_000, puntos_dia=0,
            )
        corregir(poliza, date(1980, 5, 17))
        self.assertEqual(goals.progreso(ana, goals.objetivo_de_la_semana(lunes)).pasos, 70_000)

    def test_una_fila_sin_veredicto_sigue_calculandose_con_la_regla(self):
        ana = crear_usuario(declarada=date(1988, 5, 17))
        poliza_de(ana, REAL, retroactivo="")             # creada a mano o anterior a este campo
        self.assertEqual(polizas.fecha_corte_sin_retroactivo(ana), timezone.localdate())


class FechaEfectivaTests(TestCase):
    def setUp(self):
        version()
        self.ana = crear_usuario(declarada=REAL)
        self.poliza = poliza_de(self.ana, date(1990, 1, 1), retroactivo=RETRO.APLICADO)

    def test_sin_correcciones_es_la_confirmada(self):
        self.assertEqual(fecha_nacimiento_efectiva(self.ana), date(1990, 1, 1))
        self.assertEqual(fecha_nacimiento_efectiva(self.ana, HOY), date(1990, 1, 1))

    def test_antes_de_la_correccion_vale_la_fecha_de_entonces_y_desde_ella_la_nueva(self):
        corregir(self.poliza, date(1985, 1, 1), desde=date(2026, 10, 1))
        self.assertEqual(fecha_nacimiento_efectiva(self.ana, date(2026, 9, 30)), date(1990, 1, 1))
        self.assertEqual(fecha_nacimiento_efectiva(self.ana, date(2026, 10, 1)), date(1985, 1, 1))
        self.assertEqual(fecha_nacimiento_efectiva(self.ana, date(2026, 12, 1)), date(1985, 1, 1))
        self.assertEqual(fecha_nacimiento_efectiva(self.ana), date(1985, 1, 1))

    def test_dos_correcciones_encadenan_las_fechas_de_cada_tramo(self):
        corregir(self.poliza, date(1985, 1, 1), desde=date(2026, 8, 1))        # 1990 -> 1985
        corregir(self.poliza, date(1980, 1, 1), desde=date(2026, 10, 1))       # 1985 -> 1980
        self.assertEqual(fecha_nacimiento_efectiva(self.ana, date(2026, 7, 31)), date(1990, 1, 1))
        self.assertEqual(fecha_nacimiento_efectiva(self.ana, date(2026, 9, 15)), date(1985, 1, 1))
        self.assertEqual(fecha_nacimiento_efectiva(self.ana, date(2026, 10, 1)), date(1980, 1, 1))

    def test_sin_poliza_verificada_es_la_del_registro_aunque_haya_correcciones(self):
        corregir(self.poliza, date(1985, 1, 1))
        PolizaVinculada.objects.filter(pk=self.poliza.pk).update(estado_verificacion=PENDIENTE)
        self.assertEqual(fecha_nacimiento_efectiva(self.ana, HOY), REAL)

    def test_el_perfil_muestra_la_fecha_vigente_hoy(self):
        corregir(self.poliza, date(1985, 1, 1))
        self.assertEqual(perfil.resumen(self.ana)["fecha_nacimiento"], "1985-01-01")

    def test_la_meta_de_pasos_de_una_semana_anterior_a_la_correccion_usa_la_fecha_de_entonces(self):
        poliza = poliza_de(crear_usuario("beto", date(1960, 1, 1)), A_LOS_60, numero="P-BETO", retroactivo=RETRO.TOLERADO)
        beto = poliza.usuario
        corregir(poliza, A_LOS_59, desde=HOY)           # a partir de hoy tiene 59 en vez de 60
        pasada = goals.objetivo_de_la_semana(inicio_semana(HOY) - timedelta(days=7))
        proxima = goals.objetivo_de_la_semana(inicio_semana(HOY) + timedelta(days=7))
        self.assertEqual(goals.meta_pasos_de(beto, pasada), goals.meta_pasos_para_edad(60))
        self.assertEqual(goals.meta_pasos_de(beto, proxima), goals.meta_pasos_para_edad(59))
        self.assertNotEqual(goals.meta_pasos_para_edad(60), goals.meta_pasos_para_edad(59))


class NadieDejaDePerderPuntosPorLaCorreccionTests(APITestCase):
    """Sincronizar tarde un día anterior a la corrección sigue usando la fecha de entonces."""

    def setUp(self):
        self.version = version()
        self.usuario = crear_usuario(declarada=A_LOS_60)
        self.poliza = poliza_de(self.usuario, A_LOS_60, retroactivo=RETRO.APLICADO)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=self.usuario.user).key}")
        self.ayer = HOY - timedelta(days=1)

    def pasos(self, externo, dia, cantidad, hora=8):
        base = datetime(dia.year, dia.month, dia.day, tzinfo=GT)
        return {
            "external_id": externo, "inicio": (base + timedelta(hours=hora)).isoformat(),
            "fin": (base + timedelta(hours=hora + 0.5)).isoformat(), "cantidad": cantidad,
            "fuente_bundle": "com.apple.health", "fuente_nombre": "iPhone",
            "dispositivo_modelo": "iPhone", "dispositivo_fabricante": "Apple Inc.",
        }

    def sync(self, dia, pasos):
        r = self.client.post("/api/v1/sync", {
            "fecha": dia.isoformat(), "zona_horaria": "America/Guatemala",
            "sincronizado_en": datetime.combine(HOY, datetime.min.time(), tzinfo=GT).isoformat(),
            "app_version": "1.0.0", "pasos": pasos, "sesiones": [], "frecuencia_cardiaca": [],
        }, format="json")
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def puntos(self, dia):
        return sum(Ledger.objects.filter(usuario=self.usuario, fecha=dia).values_list("puntos", flat=True))

    def test_el_bono_de_los_60_de_un_dia_anterior_se_conserva_aunque_la_fecha_corregida_ya_no_lo_de(self):
        primero = self.sync(self.ayer, [self.pasos("a1", self.ayer, 8000)])
        self.assertEqual(primero["puntos_pasos"], 50)                       # 25 + 25 del bono 60+

        corregir(self.poliza, A_LOS_59, desde=HOY)                          # ahora tiene 59: sin bono desde hoy

        tarde = self.sync(self.ayer, [self.pasos("a1", self.ayer, 8000), self.pasos("a2", self.ayer, 200, hora=20)])
        self.assertEqual(tarde["puntos_pasos"], 50)                         # ayer sigue con la fecha de entonces
        self.assertEqual(self.puntos(self.ayer), 50)

    def test_desde_la_correccion_se_usa_la_fecha_nueva(self):
        corregir(self.poliza, A_LOS_59, desde=HOY)
        r = self.sync(HOY, [self.pasos("h1", HOY, 8000)])
        self.assertEqual(r["puntos_pasos"], 25)                             # 59 años: sin bono

    def test_el_dia_de_la_correccion_ya_usa_la_fecha_nueva(self):
        corregir(self.poliza, A_LOS_59, desde=self.ayer)
        self.assertEqual(self.sync(self.ayer, [self.pasos("a", self.ayer, 8000)])["puntos_pasos"], 25)
        self.assertEqual(self.sync(self.ayer - timedelta(days=1), [
            self.pasos("b", self.ayer - timedelta(days=1), 8000),
        ])["puntos_pasos"], 50)                                             # el día anterior, la de entonces


class AdminCorrigeLaFechaTests(TestCase):
    def setUp(self):
        version()
        self.ana = crear_usuario(declarada=REAL)
        self.poliza = poliza_de(self.ana, REAL, retroactivo=RETRO.APLICADO)
        self.admin = PolizaVinculadaAdmin(PolizaVinculada, site)
        self.root = User.objects.create_superuser("root", password="x")

    def request(self):
        request = RequestFactory().post("/admin/")
        request.user = self.root
        request.session = {}
        request._messages = FallbackStorage(request)
        return request

    def guardar(self, poliza, **cambios):
        request = self.request()
        for campo, valor in cambios.items():
            setattr(poliza, campo, valor)
        self.admin.save_model(request, poliza, form=None, change=True)
        return [str(m) for m in request._messages]

    def test_cambiar_la_fecha_de_una_verificada_deja_registrada_la_correccion(self):
        mensajes = self.guardar(self.poliza, birth_date_confirmada=date(1989, 1, 1))
        correccion = CorreccionDeNacimiento.objects.get()
        self.assertEqual((correccion.fecha_anterior, correccion.fecha_nueva, correccion.desde), (REAL, date(1989, 1, 1), HOY))
        self.assertIn("no se le quita nada", mensajes[0])

    def test_no_se_registra_nada_si_la_fecha_no_cambia(self):
        self.guardar(self.poliza, plan="Oro")
        self.assertFalse(CorreccionDeNacimiento.objects.exists())

    def test_no_se_registra_en_una_poliza_pendiente_que_todavia_se_esta_llenando(self):
        pendiente = poliza_de(crear_usuario("beto"), None, estado=PENDIENTE, numero="P-OTRA")
        self.guardar(pendiente, birth_date_confirmada=REAL)
        self.assertFalse(CorreccionDeNacimiento.objects.exists())

    def test_dos_cambios_son_dos_correcciones_en_orden(self):
        self.guardar(self.poliza, birth_date_confirmada=date(1989, 1, 1))
        self.guardar(self.poliza, birth_date_confirmada=date(1988, 1, 1))
        self.assertEqual(
            list(CorreccionDeNacimiento.objects.values_list("fecha_anterior", "fecha_nueva")),
            [(REAL, date(1989, 1, 1)), (date(1989, 1, 1), date(1988, 1, 1))],
        )

    def test_el_veredicto_no_se_puede_editar_a_mano(self):
        self.assertIn("retroactivo", self.admin.readonly_fields)
        self.assertIn("corte_retroactivo", self.admin.readonly_fields)

    def test_el_historial_de_correcciones_se_ve_en_la_ficha_y_no_se_edita(self):
        inline = self.admin.inlines[0]
        self.assertIs(inline.model, CorreccionDeNacimiento)
        self.assertFalse(inline(PolizaVinculada, site).has_add_permission(self.request()))

    def test_la_correccion_no_cambia_el_veredicto(self):
        self.guardar(self.poliza, birth_date_confirmada=date(1970, 1, 1))
        self.poliza.refresh_from_db()
        self.assertEqual(self.poliza.retroactivo, RETRO.APLICADO)
        self.assertIsNone(polizas.fecha_corte_sin_retroactivo(self.ana))


class MigracionDeVeredictosTests(TestCase):
    def test_fija_el_veredicto_que_ya_se_les_habia_aplicado(self):
        migracion = import_module("Apps.policies.migrations.0008_retroactivo_congelado_y_correcciones")
        version()
        igual = poliza_de(crear_usuario("igual", REAL), REAL, numero="P-1")
        distinta = poliza_de(crear_usuario("distinta", date(1988, 5, 17)), REAL, numero="P-2")
        distinta.fecha_verificacion = datetime(2026, 9, 24, 20, 0, tzinfo=GT)       # 25 sep en UTC
        distinta.save()
        pendiente = poliza_de(crear_usuario("pend", REAL), REAL, estado=PENDIENTE, numero="P-3")
        sin_fecha = poliza_de(crear_usuario("sinfecha", REAL), None, numero="P-4")
        PolizaVinculada.objects.update(retroactivo="", corte_retroactivo=None)         # como estaban antes

        migracion.fijar_el_veredicto_de_las_verificadas(apps, None)

        for p in (igual, distinta, pendiente, sin_fecha):
            p.refresh_from_db()
        self.assertEqual((igual.retroactivo, igual.corte_retroactivo), (RETRO.APLICADO, None))
        self.assertEqual((distinta.retroactivo, distinta.corte_retroactivo), (RETRO.DENEGADO, date(2026, 9, 24)))
        self.assertEqual(pendiente.retroactivo, "")
        self.assertEqual(sin_fecha.retroactivo, "")

    def test_correrla_dos_veces_da_lo_mismo(self):
        migracion = import_module("Apps.policies.migrations.0008_retroactivo_congelado_y_correcciones")
        poliza_de(crear_usuario("distinta", date(1988, 5, 17)), REAL)
        PolizaVinculada.objects.update(retroactivo="", corte_retroactivo=None)
        migracion.fijar_el_veredicto_de_las_verificadas(apps, None)
        migracion.fijar_el_veredicto_de_las_verificadas(apps, None)
        self.assertEqual(PolizaVinculada.objects.get().retroactivo, RETRO.DENEGADO)


class VincularPorLaApiGuardaElVeredictoTests(APITestCase):
    def setUp(self):
        version()
        RegistroAseguradora.objects.create(
            numero_poliza="POL-X", aseguradora="Seguros Demo", nombre="Ana", apellido="Martínez",
            fecha_nacimiento=REAL, plan="Oro", prima_anual_gtq=Decimal("6000.00"),
            deducible_gtq=Decimal("1000"), coaseguro_pct=20, red="Red A",
            vigencia_inicio=date(2026, 1, 1), vigencia_fin=date(2027, 1, 1), estado="vigente",
        )

    def vincular(self, declarada):
        usuario = crear_usuario(f"u{declarada.year}", declarada)
        cliente = APIClient()
        cliente.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=usuario.user).key}")
        r = cliente.post("/api/v1/polizas/vincular", {
            "policy_number": "POL-X", "insurer": "Seguros Demo", "birth_date": REAL.isoformat(),
        }, format="json")
        self.assertEqual(r.status_code, 200, r.content)
        return PolizaVinculada.objects.get(usuario=usuario)

    def test_cada_caso_queda_con_su_veredicto(self):
        self.assertEqual(self.vincular(REAL).retroactivo, RETRO.APLICADO)

    def test_un_error_tolerado(self):
        self.assertEqual(self.vincular(date(1991, 5, 17)).retroactivo, RETRO.TOLERADO)

    def test_una_mentira_con_su_corte(self):
        poliza = self.vincular(date(1988, 5, 17))
        self.assertEqual((poliza.retroactivo, poliza.corte_retroactivo), (RETRO.DENEGADO, timezone.localdate()))
