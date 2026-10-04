"""Pruebas de la verificación de pólizas contra el registro SIMULADO.

Usan el CSV de ejemplo (fixtures/registro_aseguradora.csv). La fecha de "hoy"
se fija en 2026-09-30 para que las vigencias no dependan del día en que se
corran las pruebas.
"""
import csv
import datetime
import tempfile
from io import StringIO
from pathlib import Path
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import IntegrityError, transaction
from django.test import SimpleTestCase, TestCase
from django.urls import reverse
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.policies.models import PolizaVinculada, RegistroAseguradora
from Apps.users.models import Usuario
from services import policy_verification as pv
from services import polizas

CSV_EJEMPLO = Path(__file__).parent / "fixtures" / "registro_aseguradora.csv"
HOY = datetime.date(2026, 9, 30)
ASEGURADORA = "Seguros Demo GT"
D = datetime.date


def cargar_ejemplo():
    call_command("cargar_registro_aseguradora", str(CSV_EJEMPLO), stdout=StringIO())


class VincularPolizaTests(APITestCase):
    url = "/api/v1/polizas/vincular"

    def setUp(self):
        cargar_ejemplo()
        patcher = mock.patch("services.policy_verification._hoy", return_value=HOY)
        patcher.start()
        self.addCleanup(patcher.stop)

    def nuevo_usuario(self, nombre="ana", nacimiento=D(1990, 1, 1)):
        user = get_user_model().objects.create_user(nombre, password="x")
        usuario = Usuario.objects.create(
            user=user, usuario_id=f"id-{nombre}", birth_date=nacimiento
        )
        return usuario, Token.objects.get(user=user)

    def vincular(self, token, numero, nacimiento, aseguradora=ASEGURADORA, **extra):
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        cuerpo = {"policy_number": numero, "insurer": aseguradora, "birth_date": nacimiento}
        cuerpo.update(extra)
        return self.client.post(self.url, cuerpo, format="json")

    # --- Una prueba por fila del CSV: las tres vigentes se verifican ------

    def verificar_fila(self, numero, nacimiento, inicio):
        usuario, token = self.nuevo_usuario()

        respuesta = self.vincular(token, numero, nacimiento)

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta.json(), {"estado_verificacion": "verificada", "motivo_rechazo": None})
        poliza = usuario.poliza
        self.assertEqual(poliza.estado_verificacion, "verificada")
        self.assertEqual(poliza.birth_date_confirmada, D.fromisoformat(nacimiento))
        self.assertEqual(poliza.policy_start_date, inicio)
        self.assertIsNotNone(poliza.fecha_verificacion)
        self.assertIsNone(poliza.motivo_rechazo)

    def test_pol_100001_vigente_se_verifica(self):
        self.verificar_fila("POL-100001", "1994-03-12", D(2026, 1, 15))

    def test_pol_100002_vigente_se_verifica(self):
        self.verificar_fila("POL-100002", "1985-07-25", D(2026, 3, 1))

    def test_pol_100003_vigente_se_verifica(self):
        self.verificar_fila("POL-100003", "1962-11-02", D(2026, 6, 10))

    # --- Las otras tres filas se rechazan por no estar vigentes -----------

    def rechazar_fila(self, numero, nacimiento, motivo):
        usuario, token = self.nuevo_usuario()

        respuesta = self.vincular(token, numero, nacimiento)

        self.assertEqual(respuesta.status_code, 200)
        self.assertEqual(respuesta.json(), {"estado_verificacion": "rechazada", "motivo_rechazo": motivo})
        poliza = usuario.poliza
        self.assertEqual(poliza.estado_verificacion, "rechazada")
        self.assertEqual(poliza.motivo_rechazo, motivo)
        # Una póliza rechazada no guarda nada confirmado por la aseguradora.
        self.assertIsNone(poliza.birth_date_confirmada)
        self.assertIsNone(poliza.policy_start_date)
        for campo in ("nombre", "apellido", "plan", "prima_anual_gtq", "fecha_renovacion"):
            self.assertIsNone(getattr(poliza, campo), campo)

    def test_pol_100004_con_la_renovacion_ya_pasada_se_verifica(self):
        # Su fecha de renovación (28 feb 2026) ya pasó: la póliza se renovó y
        # sigue valiendo. Antes se rechazaba como "vencida" (2 oct 2026).
        self.verificar_fila("POL-100004", "1990-05-30", D(2025, 3, 1))

    def test_al_verificar_guarda_lo_que_entrega_la_aseguradora(self):
        usuario, token = self.nuevo_usuario()
        self.vincular(token, "POL-100001", "1994-03-12")
        poliza = usuario.poliza
        self.assertEqual(
            (poliza.nombre, poliza.apellido, poliza.plan),
            ("Ana", "Morales", "Plan Plus"),
        )
        self.assertEqual(str(poliza.prima_anual_gtq), "15000.00")
        self.assertEqual(poliza.fecha_renovacion, D(2027, 1, 14))

    def test_el_estado_devuelve_los_datos_de_la_poliza(self):
        usuario, token = self.nuevo_usuario()
        self.vincular(token, "POL-100001", "1994-03-12")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
        datos = self.client.get("/api/v1/polizas/estado").json()
        self.assertTrue(datos["verificada"])
        self.assertEqual(datos["poliza"], {
            "policy_number": "POL-100001",
            "insurer": "Seguros Demo GT",
            "policy_start_date": "2026-01-15",
            "nombre": "Ana",
            "apellido": "Morales",
            "plan": "Plan Plus",
            "prima_anual_gtq": "15000.00",
            # La próxima renovación desde hoy: 14 ene 2027, o la del año siguiente
            # si esta prueba corre después de esa fecha.
            "fecha_renovacion": polizas.proxima_renovacion(D(2027, 1, 14)).isoformat(),
        })

    def test_el_estado_devuelve_la_proxima_renovacion_aunque_la_guardada_ya_paso(self):
        usuario, token = self.nuevo_usuario()
        self.vincular(token, "POL-100004", "1990-05-30")  # renovación guardada: 28 feb 2026
        self.assertEqual(usuario.poliza.fecha_renovacion, D(2026, 2, 28))  # se guarda tal cual
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
        devuelta = self.client.get("/api/v1/polizas/estado").json()["poliza"]["fecha_renovacion"]
        self.assertEqual(devuelta, polizas.proxima_renovacion(D(2026, 2, 28)).isoformat())
        self.assertGreaterEqual(D.fromisoformat(devuelta), datetime.date.today())

    def test_volver_a_vincular_tras_un_rechazo_no_arrastra_datos_viejos(self):
        usuario, token = self.nuevo_usuario()
        self.vincular(token, "POL-100005", "1998-09-18")  # cancelada: rechazada
        poliza = usuario.poliza
        poliza.refresh_from_db()
        self.assertIsNone(poliza.prima_anual_gtq)
        self.vincular(token, "POL-100002", "1985-07-25")  # ahora sí
        poliza.refresh_from_db()
        self.assertEqual(poliza.estado_verificacion, "verificada")
        self.assertEqual(str(poliza.prima_anual_gtq), "9360.00")

    def test_pol_100005_cancelada_se_rechaza(self):
        self.rechazar_fila("POL-100005", "1998-09-18", "no_vigente")

    def test_pol_100006_suspendida_se_rechaza(self):
        self.rechazar_fila("POL-100006", "1979-01-08", "no_vigente")

    # --- Otros rechazos ---------------------------------------------------

    def test_fecha_de_nacimiento_distinta_se_rechaza(self):
        self.rechazar_fila("POL-100001", "1994-03-13", "fecha_nacimiento_no_coincide")

    def test_poliza_inexistente_se_rechaza(self):
        self.rechazar_fila("POL-999999", "1994-03-12", "no_existe")

    def test_aseguradora_distinta_se_rechaza(self):
        usuario, token = self.nuevo_usuario()

        respuesta = self.vincular(token, "POL-100001", "1994-03-12", aseguradora="Otra Aseguradora")

        self.assertEqual(respuesta.json()["motivo_rechazo"], "aseguradora_no_coincide")
        self.assertEqual(usuario.poliza.estado_verificacion, "rechazada")

    def test_sin_token_da_401(self):
        self.client.credentials()

        respuesta = self.client.post(
            self.url,
            {"policy_number": "POL-100001", "insurer": ASEGURADORA, "birth_date": "1994-03-12"},
            format="json",
        )

        self.assertEqual(respuesta.status_code, 401)
        self.assertEqual(PolizaVinculada.objects.count(), 0)

    def test_token_inventado_da_401(self):
        self.client.credentials(HTTP_AUTHORIZATION="Token no-existe")

        respuesta = self.client.post(self.url, {}, format="json")

        self.assertEqual(respuesta.status_code, 401)

    # --- Una póliza puede estar en más de un usuario (pólizas familiares) --

    def test_la_misma_poliza_se_vincula_a_dos_usuarios(self):
        _, token_ana = self.nuevo_usuario("ana")
        _, token_beto = self.nuevo_usuario("beto")

        r1 = self.vincular(token_ana, "POL-100001", "1994-03-12")
        r2 = self.vincular(token_beto, "POL-100001", "1994-03-12")

        self.assertEqual(r1.json()["estado_verificacion"], "verificada")
        self.assertEqual(r2.json()["estado_verificacion"], "verificada")
        self.assertEqual(PolizaVinculada.objects.filter(policy_number="POL-100001").count(), 2)

    def test_rechazar_a_un_usuario_no_afecta_al_otro(self):
        ana, token_ana = self.nuevo_usuario("ana")
        beto, token_beto = self.nuevo_usuario("beto")

        self.vincular(token_ana, "POL-100001", "1994-03-12")
        self.vincular(token_beto, "POL-100001", "1990-01-01")

        self.assertEqual(ana.poliza.estado_verificacion, "verificada")
        self.assertEqual(beto.poliza.estado_verificacion, "rechazada")

    # --- Reintentos y póliza ya verificada --------------------------------

    def test_despues_de_un_rechazo_se_puede_reintentar_y_verificar(self):
        usuario, token = self.nuevo_usuario()
        self.vincular(token, "POL-100001", "1994-03-13")  # fecha mal escrita

        respuesta = self.vincular(token, "POL-100001", "1994-03-12")

        self.assertEqual(respuesta.json(), {"estado_verificacion": "verificada", "motivo_rechazo": None})
        self.assertEqual(PolizaVinculada.objects.filter(usuario=usuario).count(), 1)
        usuario.poliza.refresh_from_db()
        self.assertIsNone(usuario.poliza.motivo_rechazo)
        self.assertEqual(usuario.poliza.policy_start_date, D(2026, 1, 15))

    def test_con_poliza_verificada_no_se_puede_cambiar_da_409(self):
        usuario, token = self.nuevo_usuario()
        self.vincular(token, "POL-100001", "1994-03-12")

        respuesta = self.vincular(token, "POL-100002", "1985-07-25")

        self.assertEqual(respuesta.status_code, 409)
        usuario.poliza.refresh_from_db()
        self.assertEqual(usuario.poliza.policy_number, "POL-100001")
        self.assertEqual(usuario.poliza.estado_verificacion, "verificada")

    # --- Identidad y validación del cuerpo --------------------------------

    def test_el_usuario_sale_del_token_no_del_cuerpo(self):
        ana, token_ana = self.nuevo_usuario("ana")
        beto, _ = self.nuevo_usuario("beto")

        self.vincular(token_ana, "POL-100001", "1994-03-12", usuario=beto.pk, usuario_id="id-beto")

        self.assertTrue(PolizaVinculada.objects.filter(usuario=ana).exists())
        self.assertFalse(PolizaVinculada.objects.filter(usuario=beto).exists())

    def test_cuenta_sin_perfil_de_usuario_da_403(self):
        user = get_user_model().objects.create_user("suelto", password="x")
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=user).key}")

        respuesta = self.client.post(
            self.url,
            {"policy_number": "POL-100001", "insurer": ASEGURADORA, "birth_date": "1994-03-12"},
            format="json",
        )

        self.assertEqual(respuesta.status_code, 403)

    def test_faltan_datos_da_400(self):
        _, token = self.nuevo_usuario()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

        respuesta = self.client.post(self.url, {"policy_number": "POL-100001"}, format="json")

        self.assertEqual(respuesta.status_code, 400)
        self.assertIn("insurer", respuesta.json())
        self.assertIn("birth_date", respuesta.json())

    def test_fecha_mal_escrita_da_400(self):
        _, token = self.nuevo_usuario()

        respuesta = self.vincular(token, "POL-100001", "12-03-1994")

        self.assertEqual(respuesta.status_code, 400)
        self.assertEqual(PolizaVinculada.objects.count(), 0)

    def test_solo_acepta_post(self):
        _, token = self.nuevo_usuario()
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

        self.assertEqual(self.client.get(self.url).status_code, 405)

    def test_mayusculas_y_espacios_no_importan(self):
        usuario, token = self.nuevo_usuario()

        respuesta = self.vincular(token, "  pol-100001 ", "1994-03-12", aseguradora=" SEGUROS demo gt ")

        self.assertEqual(respuesta.json()["estado_verificacion"], "verificada")

    def test_guarda_el_numero_oficial_de_la_aseguradora(self):
        usuario, token = self.nuevo_usuario()

        self.vincular(token, "  pol-100001 ", "1994-03-12")

        # No "pol-100001" como lo escribió el usuario, sino el de la aseguradora.
        self.assertEqual(usuario.poliza.policy_number, "POL-100001")

    def test_si_se_rechaza_guarda_lo_que_escribio_el_usuario(self):
        usuario, token = self.nuevo_usuario()

        self.vincular(token, " pol-999999 ", "1994-03-12")

        self.assertEqual(usuario.poliza.policy_number, "pol-999999")

    def test_no_se_registran_datos_personales_en_el_log(self):
        _, token = self.nuevo_usuario()

        with self.assertNoLogs(level="DEBUG"):
            self.vincular(token, "POL-100001", "1994-03-12")


class ServicioVerificacionTests(SimpleTestCase):
    """La lógica sin base de datos: una fuente falsa reemplaza a la tabla.

    Sirve también de prueba de que la fuente se puede cambiar (por la API real
    de la aseguradora) sin tocar la verificación.
    """

    class FuenteFalsa:
        def __init__(self, datos=None):
            self.datos = datos

        def buscar(self, numero_poliza):
            return self.datos

    def datos(self, **cambios):
        base = dict(
            numero_poliza="POL-1",
            aseguradora="Seguros Demo GT",
            fecha_nacimiento=D(1994, 3, 12),
            vigencia_inicio=D(2026, 1, 15),
            vigencia_fin=D(2027, 1, 14),
            vigente=True,
        )
        base.update(cambios)
        return pv.DatosPoliza(**base)

    def verificar(self, datos, hoy=HOY, insurer="Seguros Demo GT", nacimiento=D(1994, 3, 12)):
        return pv.verificar_poliza(
            None, "POL-1", insurer, nacimiento, hoy=hoy, fuente=self.FuenteFalsa(datos)
        )

    def test_todo_correcto_se_verifica(self):
        self.assertEqual(self.verificar(self.datos()), ("verificada", None))

    def test_no_existe(self):
        self.assertEqual(self.verificar(None), ("rechazada", "no_existe"))

    def test_aseguradora_distinta(self):
        self.assertEqual(self.verificar(self.datos(), insurer="Otra"), ("rechazada", "aseguradora_no_coincide"))

    def test_fecha_de_nacimiento_distinta(self):
        self.assertEqual(
            self.verificar(self.datos(), nacimiento=D(1990, 1, 1)),
            ("rechazada", "fecha_nacimiento_no_coincide"),
        )

    def test_estado_no_vigente(self):
        self.assertEqual(self.verificar(self.datos(vigente=False)), ("rechazada", "no_vigente"))

    def test_el_primer_dia_de_vigencia_cuenta(self):
        self.assertEqual(self.verificar(self.datos(), hoy=D(2026, 1, 15)), ("verificada", None))

    def test_el_ultimo_dia_de_vigencia_cuenta(self):
        self.assertEqual(self.verificar(self.datos(), hoy=D(2027, 1, 14)), ("verificada", None))

    def test_pasada_la_fecha_de_renovacion_sigue_valiendo(self):
        # La póliza es anual y se renueva: no vence (2 oct 2026).
        self.assertEqual(self.verificar(self.datos(), hoy=D(2027, 1, 15)), ("verificada", None))
        self.assertEqual(self.verificar(self.datos(), hoy=D(2030, 6, 1)), ("verificada", None))

    def test_las_fechas_no_deciden_solo_el_estado(self):
        self.assertEqual(self.verificar(self.datos(), hoy=D(2026, 1, 14)), ("verificada", None))
        self.assertEqual(
            self.verificar(self.datos(vigente=False), hoy=D(2026, 6, 1)),
            ("rechazada", "no_vigente"),
        )

    def test_si_fallan_varias_cosas_gana_el_primer_motivo(self):
        # aseguradora mal + fecha mal -> aseguradora; cancelada + fecha mal -> no_vigente
        self.assertEqual(
            self.verificar(self.datos(), insurer="Otra", nacimiento=D(1990, 1, 1)),
            ("rechazada", "aseguradora_no_coincide"),
        )
        self.assertEqual(
            self.verificar(self.datos(vigente=False), nacimiento=D(1990, 1, 1)),
            ("rechazada", "no_vigente"),
        )

    def test_verificar_con_datos_devuelve_lo_que_dijo_la_aseguradora(self):
        datos = self.datos()

        resultado = pv.verificar_con_datos(
            "POL-1", "Seguros Demo GT", D(1994, 3, 12), hoy=HOY, fuente=self.FuenteFalsa(datos)
        )

        self.assertEqual(resultado.datos, datos)
        self.assertIsNone(resultado.motivo)


class CargarRegistroAseguradoraTests(TestCase):
    def csv_temporal(self, filas, columnas=None, bom=False):
        columnas = columnas or list(csv.DictReader(CSV_EJEMPLO.open(encoding="utf-8")).fieldnames)
        archivo = tempfile.NamedTemporaryFile("w", suffix=".csv", delete=False, encoding="utf-8-sig" if bom else "utf-8", newline="")
        self.addCleanup(Path(archivo.name).unlink)
        escritor = csv.DictWriter(archivo, fieldnames=columnas)
        escritor.writeheader()
        escritor.writerows(filas)
        archivo.close()
        return archivo.name

    def filas_ejemplo(self):
        return list(csv.DictReader(CSV_EJEMPLO.open(encoding="utf-8")))

    def cargar(self, ruta):
        salida = StringIO()
        call_command("cargar_registro_aseguradora", ruta, stdout=salida)
        return salida.getvalue()

    # --- Carga ------------------------------------------------------------

    def test_carga_las_seis_polizas_del_ejemplo(self):
        salida = self.cargar(str(CSV_EJEMPLO))

        self.assertEqual(RegistroAseguradora.objects.count(), 6)
        self.assertIn("6 pólizas creadas, 0 actualizadas", salida)

    def test_guarda_los_datos_con_su_tipo_y_acentos(self):
        self.cargar(str(CSV_EJEMPLO))

        r = RegistroAseguradora.objects.get(numero_poliza="POL-100002")
        self.assertEqual((r.nombre, r.apellido, r.plan), ("Carlos", "Pérez", "Plan Básico"))
        self.assertEqual(r.fecha_nacimiento, D(1985, 7, 25))
        self.assertEqual(str(r.prima_anual_gtq), "9360.00")  # 780 al mes x 12
        self.assertEqual(r.coaseguro_pct, 20)
        self.assertEqual(r.estado, "vigente")

    def test_cada_estado_del_ejemplo_queda_como_corresponde(self):
        self.cargar(str(CSV_EJEMPLO))

        estados = dict(RegistroAseguradora.objects.values_list("numero_poliza", "estado"))
        self.assertEqual(
            estados,
            {
                "POL-100001": "vigente", "POL-100002": "vigente", "POL-100003": "vigente",
                "POL-100004": "vigente", "POL-100005": "cancelada", "POL-100006": "suspendida",
            },
        )

    # --- Se puede correr varias veces -------------------------------------

    def test_correrlo_dos_veces_no_duplica(self):
        self.cargar(str(CSV_EJEMPLO))

        salida = self.cargar(str(CSV_EJEMPLO))

        self.assertEqual(RegistroAseguradora.objects.count(), 6)
        self.assertIn("0 pólizas creadas, 6 actualizadas", salida)

    def test_actualiza_una_poliza_que_ya_existe(self):
        self.cargar(str(CSV_EJEMPLO))
        filas = self.filas_ejemplo()
        filas[0]["estado"] = "cancelada"
        filas[0]["plan"] = "Plan Nuevo"

        self.cargar(self.csv_temporal(filas))

        r = RegistroAseguradora.objects.get(numero_poliza="POL-100001")
        self.assertEqual((r.estado, r.plan), ("cancelada", "Plan Nuevo"))
        self.assertEqual(RegistroAseguradora.objects.count(), 6)

    def test_tolera_el_bom_que_agrega_excel(self):
        self.cargar(self.csv_temporal(self.filas_ejemplo(), bom=True))

        self.assertEqual(RegistroAseguradora.objects.count(), 6)

    # --- Errores: todo o nada ---------------------------------------------

    def test_una_fila_mala_no_guarda_ninguna(self):
        filas = self.filas_ejemplo()
        filas[3]["fecha_nacimiento"] = "no-es-fecha"

        with self.assertRaisesMessage(CommandError, "Fila 5"):
            self.cargar(self.csv_temporal(filas))

        self.assertEqual(RegistroAseguradora.objects.count(), 0)

    def test_estado_inventado_se_rechaza(self):
        filas = self.filas_ejemplo()
        filas[0]["estado"] = "anulada"

        with self.assertRaisesMessage(CommandError, "estado inválido"):
            self.cargar(self.csv_temporal(filas))

    def test_el_estado_vencida_ya_no_existe_y_lo_explica(self):
        filas = self.filas_ejemplo()
        filas[0]["estado"] = "vencida"

        with self.assertRaisesMessage(CommandError, "'vencida' ya no existe"):
            self.cargar(self.csv_temporal(filas))

    def test_vigencia_al_reves_se_rechaza(self):
        filas = self.filas_ejemplo()
        filas[0]["vigencia_fin"] = "2020-01-01"

        with self.assertRaisesMessage(CommandError, "vigencia_fin"):
            self.cargar(self.csv_temporal(filas))

    def test_coaseguro_fuera_de_rango_se_rechaza(self):
        filas = self.filas_ejemplo()
        filas[0]["coaseguro_pct"] = "150"

        with self.assertRaisesMessage(CommandError, "coaseguro_pct"):
            self.cargar(self.csv_temporal(filas))

    def test_faltan_columnas(self):
        columnas = ["numero_poliza", "aseguradora"]
        ruta = self.csv_temporal([{"numero_poliza": "P", "aseguradora": "A"}], columnas=columnas)

        with self.assertRaisesMessage(CommandError, "Faltan columnas"):
            self.cargar(ruta)

    def test_archivo_que_no_existe(self):
        with self.assertRaisesMessage(CommandError, "No se pudo leer"):
            self.cargar("/ruta/que/no/existe.csv")

    def test_csv_vacio(self):
        ruta = self.csv_temporal([])

        with self.assertRaisesMessage(CommandError, "no tiene filas"):
            self.cargar(ruta)


class RegistroAseguradoraModeloTests(TestCase):
    def datos(self, **cambios):
        base = dict(
            numero_poliza="POL-1", aseguradora="A", nombre="Ana", apellido="Morales",
            fecha_nacimiento=D(1994, 3, 12), plan="P", prima_anual_gtq="1200.00",
            deducible_gtq="0", coaseguro_pct=10, red="R",
            vigencia_inicio=D(2026, 1, 1), vigencia_fin=D(2026, 12, 31), estado="vigente",
        )
        base.update(cambios)
        return base

    def test_numero_de_poliza_unico(self):
        RegistroAseguradora.objects.create(**self.datos())

        with self.assertRaises(IntegrityError), transaction.atomic():
            RegistroAseguradora.objects.create(**self.datos(nombre="Otra"))

    def test_la_vigencia_no_puede_terminar_antes_de_empezar(self):
        with self.assertRaises(IntegrityError), transaction.atomic():
            RegistroAseguradora.objects.create(
                **self.datos(vigencia_inicio=D(2026, 6, 1), vigencia_fin=D(2026, 1, 1))
            )

    def test_el_coaseguro_no_pasa_de_100(self):
        with self.assertRaises(IntegrityError), transaction.atomic():
            RegistroAseguradora.objects.create(**self.datos(coaseguro_pct=101))

    def test_aparece_en_el_admin(self):
        RegistroAseguradora.objects.create(**self.datos())
        admin = get_user_model().objects.create_superuser("admin", "a@example.com", "x")
        self.client.force_login(admin)

        respuesta = self.client.get(reverse("admin:policies_registroaseguradora_changelist"))

        self.assertEqual(respuesta.status_code, 200)
        self.assertContains(respuesta, "POL-1")


class MigracionPolizaAnualTests(TestCase):
    """La migración 0006 pasa la prima a anual y quita el estado "vencida"."""

    def test_multiplica_la_prima_por_12_y_pasa_vencida_a_vigente(self):
        from importlib import import_module

        from django.apps import apps as apps_reales

        migracion = import_module("Apps.policies.migrations.0006_poliza_anual")
        r = RegistroAseguradora.objects.create(
            numero_poliza="POL-9", aseguradora="A", nombre="Ana", apellido="M",
            fecha_nacimiento=D(1994, 3, 12), plan="P", prima_anual_gtq="1250.00",
            deducible_gtq="0", coaseguro_pct=10, red="R",
            vigencia_inicio=D(2025, 3, 1), vigencia_fin=D(2026, 2, 28), estado="vencida",
        )
        migracion.a_prima_anual_y_sin_vencida(apps_reales, None)
        r.refresh_from_db()
        self.assertEqual(str(r.prima_anual_gtq), "15000.00")
        self.assertEqual(r.estado, "vigente")


class ProximaRenovacionTests(SimpleTestCase):
    def test_si_no_paso_es_la_misma(self):
        self.assertEqual(polizas.proxima_renovacion(D(2027, 1, 14), hoy=D(2026, 10, 3)), D(2027, 1, 14))

    def test_el_dia_de_la_renovacion_ya_es_la_del_anio_siguiente(self):
        # Coincide con anio_de: ese día ya es el primero del año de póliza nuevo.
        self.assertEqual(polizas.proxima_renovacion(D(2027, 1, 14), hoy=D(2027, 1, 14)), D(2028, 1, 14))

    def test_si_ya_paso_es_un_anio_despues(self):
        self.assertEqual(polizas.proxima_renovacion(D(2026, 2, 28), hoy=D(2026, 10, 3)), D(2027, 2, 28))

    def test_si_pasaron_varios_anios_salta_los_que_hagan_falta(self):
        self.assertEqual(polizas.proxima_renovacion(D(2023, 5, 1), hoy=D(2026, 10, 3)), D(2027, 5, 1))

    def test_29_de_febrero_cae_en_28_si_el_anio_no_es_bisiesto(self):
        self.assertEqual(polizas.proxima_renovacion(D(2024, 2, 29), hoy=D(2024, 3, 1)), D(2025, 2, 28))
        self.assertEqual(polizas.proxima_renovacion(D(2024, 2, 29), hoy=D(2027, 6, 1)), D(2028, 2, 29))

    def test_sin_fecha_devuelve_none(self):
        self.assertIsNone(polizas.proxima_renovacion(None))
