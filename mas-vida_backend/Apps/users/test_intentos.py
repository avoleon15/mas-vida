"""Límite de intentos en registro, login y vinculación de póliza (etapa 10, 4 oct 2026)."""
from datetime import date, datetime, timedelta, timezone as utc
from decimal import Decimal
from unittest import mock

from django.contrib.auth import get_user_model
from django.test import RequestFactory, SimpleTestCase, TestCase, override_settings
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient, APITestCase

from Apps.policies.models import PolizaVinculada, RegistroAseguradora
from Apps.users.models import IntentoFallido, Usuario
from services import intentos

User = get_user_model()
AHORA = datetime(2026, 10, 5, 12, 0, tzinfo=utc.utc)

REGISTRO = "/api/v1/registro"
LOGIN = "/api/v1/login"
VINCULAR = "/api/v1/polizas/vincular"


class ServicioDeIntentosTests(TestCase):
    def registrar_n(self, tipo, clave, n, desde=AHORA, cada=timedelta(seconds=1)):
        for i in range(n):
            intentos.registrar(tipo, clave, ahora=desde + i * cada)

    def test_por_debajo_del_limite_no_bloquea(self):
        self.registrar_n(intentos.LOGIN_CUENTA, "1.2.3.4", 4)
        intentos.revisar(intentos.LOGIN_CUENTA, "1.2.3.4", ahora=AHORA + timedelta(seconds=5))

    def test_al_llegar_al_limite_bloquea_y_dice_cuanto_esperar(self):
        self.registrar_n(intentos.LOGIN_CUENTA, "1.2.3.4", 5)      # a las 12:00:00 ... 12:00:04
        with self.assertRaises(intentos.Bloqueado) as contexto:
            intentos.revisar(intentos.LOGIN_CUENTA, "1.2.3.4", ahora=AHORA + timedelta(seconds=10))
        # El primero sale de la ventana de 60 s a las 12:01:00: faltan 50 s.
        self.assertEqual(contexto.exception.reintentar_en, 50)

    def test_pasada_la_ventana_se_puede_volver_a_intentar(self):
        self.registrar_n(intentos.LOGIN_CUENTA, "1.2.3.4", 5)
        intentos.revisar(intentos.LOGIN_CUENTA, "1.2.3.4", ahora=AHORA + timedelta(seconds=61))

    def test_un_intento_viejo_que_sale_de_la_ventana_libera_un_lugar(self):
        self.registrar_n(intentos.LOGIN_CUENTA, "1.2.3.4", 5, cada=timedelta(seconds=10))   # 0, 10, 20, 30, 40 s
        with self.assertRaises(intentos.Bloqueado):
            intentos.revisar(intentos.LOGIN_CUENTA, "1.2.3.4", ahora=AHORA + timedelta(seconds=50))
        intentos.revisar(intentos.LOGIN_CUENTA, "1.2.3.4", ahora=AHORA + timedelta(seconds=61))   # salió el de 0 s

    def test_pasarse_del_limite_alarga_la_espera(self):
        self.registrar_n(intentos.LOGIN_CUENTA, "1.2.3.4", 8)       # 0..7 s: 8 intentos, máximo 5
        with self.assertRaises(intentos.Bloqueado) as contexto:
            intentos.revisar(intentos.LOGIN_CUENTA, "1.2.3.4", ahora=AHORA + timedelta(seconds=10))
        # Para bajar de 8 a 4 tienen que salir 4: el cuarto (3 s) sale a los 63 s.
        self.assertEqual(contexto.exception.reintentar_en, 53)

    def test_cada_clave_y_cada_tipo_llevan_su_cuenta(self):
        self.registrar_n(intentos.LOGIN_CUENTA, "1.2.3.4", 5)
        intentos.revisar(intentos.LOGIN_CUENTA, "5.6.7.8", ahora=AHORA)
        intentos.revisar(intentos.REGISTRO_IP, "1.2.3.4", ahora=AHORA)

    def test_los_limites_de_cada_tipo(self):
        self.assertEqual(intentos.limite_de(intentos.VINCULAR_POLIZA), (5, 86_400))
        self.assertEqual(intentos.limite_de(intentos.VINCULAR_CUENTA), (5, 3_600))
        self.assertEqual(intentos.limite_de(intentos.LOGIN_CUENTA), (5, 60))
        self.assertEqual(intentos.limite_de(intentos.LOGIN_IP), (30, 60))
        self.assertEqual(intentos.limite_de(intentos.REGISTRO_IP), (30, 3_600))

    @override_settings(LIMITES_DE_INTENTOS={"login_cuenta": (2, 60)})
    def test_los_limites_se_pueden_cambiar_en_la_configuracion(self):
        self.registrar_n(intentos.LOGIN_CUENTA, "1.2.3.4", 2)
        with self.assertRaises(intentos.Bloqueado):
            intentos.revisar(intentos.LOGIN_CUENTA, "1.2.3.4", ahora=AHORA + timedelta(seconds=5))
        self.assertEqual(intentos.limite_de(intentos.REGISTRO_IP), (30, 3_600))   # el resto sigue igual

    def test_los_intentos_de_mas_de_dos_dias_se_borran(self):
        intentos.registrar(intentos.LOGIN_CUENTA, "viejo", ahora=AHORA - timedelta(days=3))
        intentos.registrar(intentos.LOGIN_CUENTA, "reciente", ahora=AHORA - timedelta(days=1))
        intentos.registrar(intentos.LOGIN_CUENTA, "nuevo", ahora=AHORA)
        self.assertEqual(
            set(IntentoFallido.objects.values_list("clave", flat=True)), {"reciente", "nuevo"},
        )

    def test_la_respuesta_bloqueada_es_un_429_con_retry_after(self):
        respuesta = intentos.Bloqueado(42).respuesta()
        self.assertEqual(respuesta.status_code, 429)
        self.assertEqual(respuesta["Retry-After"], "42")
        self.assertEqual(respuesta.data["error"], "demasiados_intentos")
        self.assertEqual(respuesta.data["reintentar_en"], 42)


class ClaveDePolizaTests(SimpleTestCase):
    def test_no_distingue_mayusculas_ni_espacios(self):
        self.assertEqual(
            intentos.clave_de_poliza("Seguros Demo", "POL-123"),
            intentos.clave_de_poliza("  seguros demo ", " pol-123 "),
        )

    def test_otra_poliza_u_otra_aseguradora_es_otra_clave(self):
        base = intentos.clave_de_poliza("Seguros Demo", "POL-123")
        self.assertNotEqual(base, intentos.clave_de_poliza("Seguros Demo", "POL-124"))
        self.assertNotEqual(base, intentos.clave_de_poliza("Otra", "POL-123"))

    def test_no_guarda_el_numero_en_claro(self):
        clave = intentos.clave_de_poliza("Seguros Demo", "POL-123")
        self.assertNotIn("POL", clave)
        self.assertEqual(len(clave), 64)


class IpDeTests(SimpleTestCase):
    def peticion(self, **meta):
        return RequestFactory().get("/", **meta)

    def test_por_defecto_es_la_direccion_de_la_conexion(self):
        self.assertEqual(intentos.ip_de(self.peticion(REMOTE_ADDR="10.0.0.9")), "10.0.0.9")

    def test_el_encabezado_reenviado_se_ignora_sin_proxies_configurados(self):
        peticion = self.peticion(REMOTE_ADDR="10.0.0.9", HTTP_X_FORWARDED_FOR="1.1.1.1")
        self.assertEqual(intentos.ip_de(peticion), "10.0.0.9")

    @override_settings(NUM_PROXIES_CONFIABLES=1)
    def test_con_un_proxy_propio_se_toma_la_ultima_direccion(self):
        # Quien falsea el encabezado solo controla lo de la izquierda.
        peticion = self.peticion(REMOTE_ADDR="10.0.0.1", HTTP_X_FORWARDED_FOR="6.6.6.6, 200.1.1.1")
        self.assertEqual(intentos.ip_de(peticion), "200.1.1.1")

    @override_settings(NUM_PROXIES_CONFIABLES=2)
    def test_con_dos_proxies_se_toma_la_penultima(self):
        peticion = self.peticion(HTTP_X_FORWARDED_FOR="6.6.6.6, 200.1.1.1, 10.0.0.5")
        self.assertEqual(intentos.ip_de(peticion), "200.1.1.1")

    @override_settings(NUM_PROXIES_CONFIABLES=1)
    def test_si_falta_el_encabezado_se_usa_la_conexion(self):
        self.assertEqual(intentos.ip_de(self.peticion(REMOTE_ADDR="10.0.0.9")), "10.0.0.9")


class RegistroConLimiteTests(APITestCase):
    def registrar(self, n, ip="10.0.0.1"):
        return self.client.post(REGISTRO, {
            "username": f"persona{n}@correo.com", "password": "Clave-segura-2026", "birth_date": "1990-05-17",
        }, format="json", REMOTE_ADDR=ip)

    def test_el_registro_31_en_una_hora_desde_la_misma_ip_da_429(self):
        for n in range(30):
            self.assertEqual(self.registrar(n).status_code, 201)
        r = self.registrar(30)
        self.assertEqual(r.status_code, 429)
        self.assertEqual(r.json()["error"], "demasiados_intentos")
        self.assertGreater(int(r["Retry-After"]), 0)
        self.assertFalse(User.objects.filter(username="persona30@correo.com").exists())

    def test_cuentan_tambien_los_intentos_que_salen_mal(self):
        for _ in range(30):
            self.client.post(REGISTRO, {"username": "x"}, format="json", REMOTE_ADDR="10.0.0.1")
        self.assertEqual(self.registrar(1).status_code, 429)

    def test_otra_ip_no_se_ve_afectada(self):
        for n in range(30):
            self.registrar(n)
        self.assertEqual(self.registrar(99, ip="10.0.0.2").status_code, 201)

    def test_pasada_la_hora_se_puede_registrar_otra_vez(self):
        for n in range(30):
            self.registrar(n)
        siguiente = datetime.now(utc.utc) + timedelta(hours=1, minutes=1)
        with mock.patch("django.utils.timezone.now", return_value=siguiente):
            self.assertEqual(self.registrar(50).status_code, 201)


class LoginConLimiteTests(APITestCase):
    def setUp(self):
        User.objects.create_user("ana@correo.com", password="Clave-segura-2026")
        User.objects.create_user("beto@correo.com", password="Clave-segura-2026")

    def entrar(self, clave="Clave-segura-2026", ip="10.0.0.1", usuario="ana@correo.com", **extra):
        return self.client.post(
            LOGIN, {"username": usuario, "password": clave}, format="json",
            REMOTE_ADDR=ip, **extra,
        )

    def test_sigue_respondiendo_igual_cuando_todo_sale_bien_o_mal(self):
        ok = self.entrar()
        self.assertEqual(ok.status_code, 200)
        self.assertEqual(set(ok.json()), {"token"})
        malo = self.entrar("mala")
        self.assertEqual(malo.status_code, 400)
        self.assertIn("non_field_errors", malo.json())

    def test_la_sexta_contrasena_mala_para_la_misma_cuenta_en_un_minuto_da_429(self):
        for _ in range(5):
            self.assertEqual(self.entrar("mala").status_code, 400)
        r = self.entrar("mala")
        self.assertEqual(r.status_code, 429)
        self.assertEqual(r.json()["error"], "demasiados_intentos")
        self.assertEqual(r["Retry-After"], str(r.json()["reintentar_en"]))

    def test_bloqueada_la_cuenta_ni_la_contrasena_correcta_pasa(self):
        for _ in range(5):
            self.entrar("mala")
        self.assertEqual(self.entrar().status_code, 429)

    def test_con_la_misma_ip_otra_cuenta_puede_entrar(self):
        # Docker o una red de celular: mucha gente con la misma IP. Una cuenta
        # bloqueada no deja afuera a las demas.
        for _ in range(5):
            self.entrar("mala")
        self.assertEqual(self.entrar(usuario="beto@correo.com").status_code, 200)

    def test_la_misma_cuenta_desde_otra_ip_tambien_esta_bloqueada(self):
        for _ in range(5):
            self.entrar("mala", ip="10.0.0.1")
        self.assertEqual(self.entrar(ip="10.0.0.2").status_code, 429)

    def test_un_usuario_que_no_existe_cuenta_igual_y_responde_lo_mismo(self):
        # Asi el limite no sirve para saber que usuarios existen.
        for _ in range(5):
            self.assertEqual(self.entrar("x", usuario="fantasma@correo.com").status_code, 400)
        fantasma = self.entrar("x", usuario="fantasma@correo.com")
        for _ in range(5):
            self.entrar("mala")
        real = self.entrar("mala")
        self.assertEqual((fantasma.status_code, real.status_code), (429, 429))
        self.assertEqual(set(fantasma.json()), set(real.json()))

    def test_el_usuario_no_distingue_mayusculas_ni_espacios(self):
        for escrito in ("ana@correo.com", "ANA@correo.com", " Ana@Correo.com ", "ana@correo.com", "ANA@CORREO.COM"):
            self.entrar("mala", usuario=escrito)
        self.assertEqual(self.entrar("mala").status_code, 429)

    def test_la_ip_se_bloquea_con_30_fallos_repartidos_entre_muchas_cuentas(self):
        for n in range(30):
            self.assertEqual(self.entrar("mala", usuario=f"intruso{n}@correo.com").status_code, 400)
        r = self.entrar("mala", usuario="intruso99@correo.com")
        self.assertEqual(r.status_code, 429)
        # Con la IP bloqueada, ni una cuenta limpia entra desde ahi...
        self.assertEqual(self.entrar(usuario="beto@correo.com").status_code, 429)
        # ...pero desde otra IP si.
        self.assertEqual(self.entrar(usuario="beto@correo.com", ip="10.0.0.2").status_code, 200)

    def test_los_logins_que_salen_bien_no_cuentan(self):
        for _ in range(40):
            self.assertEqual(self.entrar().status_code, 200)

    def test_pasado_el_minuto_se_puede_volver_a_intentar(self):
        for _ in range(5):
            self.entrar("mala")
        siguiente = datetime.now(utc.utc) + timedelta(seconds=61)
        with mock.patch("django.utils.timezone.now", return_value=siguiente):
            self.assertEqual(self.entrar().status_code, 200)

    def test_un_token_viejo_en_el_encabezado_no_impide_entrar(self):
        r = self.entrar(HTTP_AUTHORIZATION="Token basura")
        self.assertEqual(r.status_code, 200)

    def test_un_cuerpo_que_no_es_un_objeto_no_rompe_el_servidor(self):
        r = self.client.post(LOGIN, ["ana", "clave"], format="json", REMOTE_ADDR="10.0.0.1")
        self.assertEqual(r.status_code, 400)

    def test_no_se_guarda_el_usuario_en_claro(self):
        self.entrar("mala")
        claves = list(IntentoFallido.objects.values_list("clave", flat=True))
        self.assertTrue(claves)
        for clave in claves:
            self.assertNotIn("ana", clave)
        cuenta = IntentoFallido.objects.get(tipo="login_cuenta")
        self.assertEqual(len(cuenta.clave), 64)

    @override_settings(LIMITES_DE_INTENTOS={"login_cuenta": (100, 60), "login_ip": (100, 60)})
    def test_los_limites_se_pueden_subir_para_probar_en_local(self):
        for _ in range(50):
            self.assertEqual(self.entrar("mala").status_code, 400)


class LimitesDeEntornoTests(SimpleTestCase):
    def leer(self, valor):
        from config import settings as ajustes
        with mock.patch.dict("os.environ", {"LIMITES_DE_INTENTOS": valor}):
            return ajustes._limites_de_entorno()

    def test_sin_variable_no_cambia_nada(self):
        self.assertEqual(self.leer(""), {})

    def test_lee_varios_limites(self):
        self.assertEqual(
            self.leer("login_ip=300/60, registro_ip=100/3600"),
            {"login_ip": (300, 60), "registro_ip": (100, 3600)},
        )

    def test_un_formato_roto_detiene_el_arranque_con_un_mensaje_claro(self):
        from django.core.exceptions import ImproperlyConfigured
        for roto in ("login_ip", "login_ip=300", "login_ip=a/60", "login_ip=300/60/1"):
            with self.subTest(roto=roto), self.assertRaises(ImproperlyConfigured) as contexto:
                self.leer(roto)
            self.assertIn("Formato", str(contexto.exception))


class VincularConLimiteTests(APITestCase):
    def setUp(self):
        RegistroAseguradora.objects.create(
            numero_poliza="POL-X", aseguradora="Seguros Demo", nombre="Ana", apellido="Martínez",
            fecha_nacimiento=date(1990, 5, 17), plan="Oro", prima_anual_gtq=Decimal("6000.00"),
            deducible_gtq=Decimal("1000"), coaseguro_pct=20, red="Red A",
            vigencia_inicio=date(2026, 1, 1), vigencia_fin=date(2027, 1, 1), estado="vigente",
        )
        self.titular = self.cuenta("titular")
        self.intruso = self.cuenta("intruso")

    def cuenta(self, nombre):
        user = User.objects.create_user(f"{nombre}@correo.com", password="Clave-segura-2026")
        usuario = Usuario.objects.create(user=user, usuario_id=f"id-{nombre}", birth_date=date(1990, 5, 17))
        cliente = APIClient()
        cliente.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get(user=user).key}")
        usuario.cliente = cliente
        return usuario

    def vincular(self, cuenta, nacimiento="1990-05-17", numero="POL-X", aseguradora="Seguros Demo"):
        return cuenta.cliente.post(VINCULAR, {
            "policy_number": numero, "insurer": aseguradora, "birth_date": nacimiento,
        }, format="json")

    def adivinar(self, cuenta, intentos_n):
        return [self.vincular(cuenta, f"1990-05-{dia:02d}").status_code for dia in range(1, intentos_n + 1)]

    def test_adivinando_fechas_se_corta_en_el_sexto_intento(self):
        codigos = self.adivinar(self.intruso, 10)
        self.assertEqual(codigos[:5], [200] * 5)
        self.assertEqual(codigos[5:], [429] * 5)

    def test_no_se_llega_a_probar_la_fecha_correcta(self):
        # La fecha del titular es el 17: con el límite, el intruso solo alcanza hasta el 5.
        self.adivinar(self.intruso, 5)
        r = self.vincular(self.intruso)       # la correcta, pero ya bloqueado
        self.assertEqual(r.status_code, 429)
        self.assertEqual(PolizaVinculada.objects.get(usuario=self.intruso).estado_verificacion, "rechazada")

    def test_el_limite_por_poliza_suma_todas_las_cuentas(self):
        self.adivinar(self.intruso, 3)
        otra = self.cuenta("otra")
        self.assertEqual([self.vincular(otra, f"1991-01-{d:02d}").status_code for d in (1, 2)], [200, 200])
        self.assertEqual(self.vincular(self.titular).status_code, 429)   # el número ya llegó a 5 rechazos

    def test_el_limite_por_cuenta_cuenta_rechazos_de_cualquier_poliza(self):
        codigos = [self.vincular(self.intruso, numero=f"POL-NO-{n}").status_code for n in range(7)]
        self.assertEqual(codigos, [200] * 5 + [429] * 2)

    def test_un_numero_con_otras_mayusculas_o_espacios_es_el_mismo(self):
        for dia in range(1, 6):
            self.vincular(self.intruso, f"1990-05-{dia:02d}", numero=" pol-x ")
        self.assertEqual(self.vincular(self.titular, numero="POL-X").status_code, 429)

    def test_otra_poliza_no_se_ve_afectada(self):
        self.adivinar(self.intruso, 5)
        otra_cuenta = self.cuenta("otra")
        self.assertEqual(self.vincular(otra_cuenta, numero="POL-OTRA").status_code, 200)

    def test_vincular_bien_a_la_primera_nunca_choca_con_el_limite(self):
        r = self.vincular(self.titular)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["estado_verificacion"], "verificada")
        self.assertFalse(IntentoFallido.objects.exists())

    def test_el_429_responde_igual_exista_o_no_la_poliza(self):
        for dia in range(1, 6):
            self.vincular(self.intruso, f"1990-05-{dia:02d}", numero="POL-NO-EXISTE")
        existe = self.vincular(self.intruso, numero="POL-NO-EXISTE")
        for dia in range(1, 6):
            self.vincular(self.titular, f"1990-06-{dia:02d}", numero="POL-X")
        real = self.vincular(self.intruso, numero="POL-X")
        self.assertEqual((existe.status_code, real.status_code), (429, 429))
        self.assertEqual(set(existe.json()), set(real.json()))

    def test_bloqueado_no_consulta_a_la_aseguradora(self):
        self.adivinar(self.intruso, 5)
        with mock.patch("Apps.policies.views.verificar_con_datos") as verificar:
            self.vincular(self.intruso)
        verificar.assert_not_called()

    def test_pasado_el_dia_se_puede_volver_a_intentar_la_poliza(self):
        self.adivinar(self.intruso, 5)
        otra = self.cuenta("otra")
        siguiente = datetime.now(utc.utc) + timedelta(days=1, minutes=1)
        with mock.patch("django.utils.timezone.now", return_value=siguiente):
            self.assertEqual(self.vincular(otra).status_code, 200)

    def test_los_datos_mal_formados_no_cuentan(self):
        for _ in range(8):
            r = self.intruso.cliente.post(VINCULAR, {"policy_number": "POL-X"}, format="json")
            self.assertEqual(r.status_code, 400)
        self.assertEqual(self.vincular(self.intruso, "1990-05-17").json()["estado_verificacion"], "verificada")

    def test_una_cuenta_ya_verificada_que_reintenta_no_se_cuenta(self):
        self.vincular(self.titular)
        for _ in range(8):
            self.assertEqual(self.vincular(self.titular).status_code, 409)
        self.assertFalse(IntentoFallido.objects.exists())

    def test_sin_token_sigue_siendo_401(self):
        r = APIClient().post(VINCULAR, {"policy_number": "POL-X", "insurer": "Seguros Demo", "birth_date": "1990-05-17"}, format="json")
        self.assertEqual(r.status_code, 401)
