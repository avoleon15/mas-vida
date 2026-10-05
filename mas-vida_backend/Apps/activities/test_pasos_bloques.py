"""Pasos por bloques: una muestra de más de una hora no se cuenta dos veces (etapa 11, 5 oct 2026)."""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from Apps.poincs.models import VersionRegla
from Apps.users.models import Usuario
from services.device import pasos_ganadores_por_bloque

GT = ZoneInfo("America/Guatemala")
DIA = date(2026, 10, 5)
INICIO_DIA = datetime(2026, 10, 5, tzinfo=GT)
FIN_DIA = INICIO_DIA + timedelta(days=1)

IPHONE = {"fuente_bundle": "com.apple.health", "dispositivo_modelo": "iPhone", "dispositivo_fabricante": "Apple Inc."}
WATCH = {"fuente_bundle": "com.apple.health", "dispositivo_modelo": "Watch", "dispositivo_fabricante": "Apple Inc."}
PULSERA = {"fuente_bundle": "com.fitbit", "dispositivo_modelo": "Charge", "dispositivo_fabricante": "Fitbit"}


def muestra(desde, hasta, cantidad, dispositivo=IPHONE, dia=DIA):
    """`desde` y `hasta` en horas decimales del día (8.5 = 8:30); más de 24 es el día siguiente."""
    base = datetime(dia.year, dia.month, dia.day, tzinfo=GT)
    return {
        "inicio": (base + timedelta(hours=desde)).isoformat(),
        "fin": (base + timedelta(hours=hasta)).isoformat(),
        "cantidad": cantidad,
        **dispositivo,
    }


def total(muestras, inicio_dia=INICIO_DIA, fin_dia=FIN_DIA):
    return sum(m["cantidad"] for m in pasos_ganadores_por_bloque(muestras, inicio_dia, fin_dia))


class MuestrasCortasTests(SimpleTestCase):
    """Lo que ya funcionaba por hora tiene que seguir igual."""

    def test_en_la_misma_hora_gana_el_dispositivo_con_mas_pasos_y_no_se_suman(self):
        self.assertEqual(total([muestra(8, 8.5, 6000), muestra(8.2, 8.7, 4000, WATCH)]), 6000)

    def test_el_reloj_con_mas_pasos_le_gana_al_telefono_en_esa_hora(self):
        self.assertEqual(total([muestra(8, 8.5, 4000), muestra(8.1, 8.6, 6000, WATCH)]), 6000)

    def test_las_horas_se_suman(self):
        self.assertEqual(total([muestra(8, 8.5, 3000), muestra(9, 9.5, 2000), muestra(15, 15.5, 1000)]), 6000)

    def test_un_reloj_que_solo_se_usa_en_el_gym_aporta_esa_hora(self):
        muestras = [
            muestra(9, 9.5, 6000), muestra(18, 18.5, 500),
            muestra(18, 18.5, 4000, WATCH),
        ]
        self.assertEqual(total(muestras), 6000 + 4000)

    def test_un_reloj_de_noche_no_le_quita_al_telefono_los_pasos_del_dia(self):
        self.assertEqual(total([muestra(10, 10.5, 12000), muestra(3, 3.5, 300, WATCH)]), 12300)

    def test_las_muestras_cortas_que_cruzan_la_hora_no_encadenan_el_dia(self):
        # Muestras reales del iPhone: arrancan en un minuto cualquiera y cruzan la hora.
        iphone = [muestra(h + 0.85, h + 1.15, 700) for h in range(8, 18)]     # 8:51-9:09, 9:51-10:09...
        gym = [muestra(18.1, 18.6, 4000, WATCH)]
        self.assertEqual(total(iphone + gym), 7000 + 4000)    # el gym sigue contando su hora

    def test_el_empate_exacto_siempre_da_lo_mismo(self):
        a, b = muestra(8, 8.5, 1000), muestra(8, 8.5, 1000, WATCH)
        self.assertEqual(
            pasos_ganadores_por_bloque([a, b], INICIO_DIA, FIN_DIA),
            pasos_ganadores_por_bloque([b, a], INICIO_DIA, FIN_DIA),
        )

    def test_no_modifica_las_muestras_que_recibe(self):
        original = muestra(8, 8.5, 1000)
        copia = dict(original)
        pasos_ganadores_por_bloque([original], INICIO_DIA, FIN_DIA)
        self.assertEqual(original, copia)


class MuestrasLargasTests(SimpleTestCase):
    def test_una_pulsera_que_sube_diez_horas_de_golpe_no_se_suma_al_telefono(self):
        # El hallazgo: 12.000 pasos reales se contaban como 21.800.
        telefono = [muestra(h, h + 0.5, 1200) for h in range(8, 18)]               # 12.000 en 10 horas
        pulsera = muestra(8, 18, 11000, PULSERA)
        self.assertEqual(total(telefono + [pulsera]), 12000)

    def test_si_la_pulsera_midio_mas_gana_ella_y_el_telefono_no_se_suma(self):
        telefono = [muestra(h, h + 0.5, 1200) for h in range(8, 18)]
        pulsera = muestra(8, 18, 13000, PULSERA)
        self.assertEqual(total(telefono + [pulsera]), 13000)

    def test_una_muestra_de_todo_el_dia_compara_el_dia_entero(self):
        telefono = [muestra(h, h + 0.5, 800) for h in range(8, 18)]                # 8.000
        pulsera_del_dia = muestra(0, 24, 12000, PULSERA)
        self.assertEqual(total(telefono + [pulsera_del_dia]), 12000)

    def test_una_muestra_larga_sola_cuenta_entera(self):
        self.assertEqual(total([muestra(8, 18, 11000, PULSERA)]), 11000)

    def test_los_pasos_de_antes_y_despues_del_bloque_siguen_sumando(self):
        telefono = [muestra(7, 7.5, 500), muestra(19, 19.5, 700)] + [muestra(h, h + 0.5, 1000) for h in range(8, 18)]
        pulsera = muestra(8, 18, 4000, PULSERA)                                    # pierde: el teléfono suma 10.000
        self.assertEqual(total(telefono + [pulsera]), 500 + 10000 + 700)

    def test_dos_muestras_largas_que_se_cruzan_forman_un_solo_bloque(self):
        a = muestra(8, 12, 4000, PULSERA)
        b = muestra(11, 15, 3000, PULSERA)             # comparten la hora 11
        telefono = [muestra(h, h + 0.5, 1000) for h in range(8, 15)]                # 7.000 en las 7 horas
        self.assertEqual(total([a, b] + telefono), 7000)                            # 4.000 + 3.000 de la pulsera pierden

    def test_dos_muestras_largas_pegadas_pero_sin_cruzarse_son_bloques_distintos(self):
        a = muestra(8, 10, 2000, PULSERA)               # horas 8 y 9
        b = muestra(10, 12, 2000, PULSERA)              # horas 10 y 11
        telefono_a = [muestra(8.1, 8.4, 700), muestra(9.1, 9.4, 700)]              # 1.400 en el primer bloque: pierde
        telefono_b = [muestra(10.1, 10.4, 1500), muestra(11.1, 11.4, 1500)]        # 3.000 en el segundo: gana
        self.assertEqual(total([a, b] + telefono_a + telefono_b), 2000 + 3000)

    def test_una_muestra_larga_incluye_a_las_cortas_que_caen_dentro(self):
        # El teléfono lee 9:00-9:30 en medio de un tramo largo de la pulsera: son el mismo bloque.
        self.assertEqual(total([muestra(8, 12, 3000, PULSERA), muestra(9, 9.5, 1000)]), 3000)

    def test_una_muestra_de_mas_de_una_hora_es_larga_y_una_de_justo_una_hora_no(self):
        telefono = muestra(8, 8.5, 500)
        justo_una_hora = muestra(8, 9, 400, PULSERA)       # no es larga: cuenta en la hora 8
        self.assertEqual(total([telefono, justo_una_hora]), 500)
        un_poco_mas = muestra(8, 9.05, 400, PULSERA)       # sí es larga: junta las horas 8 y 9
        telefono_9 = muestra(9, 9.5, 300)
        self.assertEqual(total([telefono, telefono_9, un_poco_mas]), 800)   # 500+300 contra 400: gana el teléfono


class CruzarLaMedianocheTests(SimpleTestCase):
    def test_se_reparte_entre_los_dos_dias_segun_el_tiempo_en_cada_uno(self):
        # 22:00 a 06:00: 2 horas en el día 5 y 6 en el 6, de 8.000 pasos.
        m = muestra(22, 30, 8000)
        siguiente = (INICIO_DIA + timedelta(days=1), INICIO_DIA + timedelta(days=2))
        self.assertEqual(total([m]), 2000)
        self.assertEqual(total([m], *siguiente), 6000)

    def test_lo_que_le_toca_a_cada_dia_suma_siempre_la_cantidad_original(self):
        for cantidad in (1, 7, 1001, 9999, 12345):
            with self.subTest(cantidad=cantidad):
                m = muestra(20, 29, cantidad)                 # 4 horas el día 5, 5 el día 6
                dia2 = (INICIO_DIA + timedelta(days=1), INICIO_DIA + timedelta(days=2))
                self.assertEqual(total([m]) + total([m], *dia2), cantidad)

    def test_una_muestra_de_varios_dias_se_reparte_en_todos(self):
        m = muestra(12, 12 + 72, 7200)                        # 3 días exactos desde el mediodía
        dias = [(INICIO_DIA + timedelta(days=i), INICIO_DIA + timedelta(days=i + 1)) for i in range(4)]
        partes = [total([m], *d) for d in dias]
        self.assertEqual(sum(partes), 7200)
        self.assertEqual(partes[1], 2400)                     # un día completo

    def test_la_parte_del_dia_compite_contra_los_demas_solo_en_su_tramo(self):
        # La pulsera cubre 22:00-06:00; en el día 5 el teléfono tiene 700 a las 23:00 (dentro del bloque).
        pulsera = muestra(22, 30, 8000, PULSERA)               # 2.000 en el día 5
        telefono = muestra(23, 23.5, 700)
        self.assertEqual(total([pulsera, telefono]), 2000)

    def test_una_muestra_que_termina_justo_a_la_medianoche_no_toca_el_dia_siguiente(self):
        m = muestra(20, 24, 4000)
        dia2 = (INICIO_DIA + timedelta(days=1), INICIO_DIA + timedelta(days=2))
        self.assertEqual((total([m]), total([m], *dia2)), (4000, 0))

    def test_una_muestra_que_no_toca_el_dia_se_ignora(self):
        self.assertEqual(total([muestra(8, 9, 1000, dia=DIA - timedelta(days=3))]), 0)

    def test_una_lectura_puntual_cuenta_entera_en_su_dia(self):
        puntual = muestra(23.999, 23.999, 50)
        otra = muestra(0, 0, 70, dia=DIA + timedelta(days=1))          # justo a las 00:00 del día 6
        dia2 = (INICIO_DIA + timedelta(days=1), INICIO_DIA + timedelta(days=2))
        self.assertEqual((total([puntual]), total([puntual], *dia2)), (50, 0))
        self.assertEqual((total([otra]), total([otra], *dia2)), (0, 70))


def crear_usuario():
    user = get_user_model().objects.create_user("ana@correo.com", password="Clave-segura-2026")
    return Usuario.objects.create(user=user, usuario_id="ana-1", birth_date=date(1990, 5, 17))


class PasosPorBloquesPorLaApiTests(APITestCase):
    def setUp(self):
        VersionRegla.objects.get_or_create(version=1, defaults={"vigente_desde": date(2026, 1, 1)})
        self.usuario = crear_usuario()
        token = Token.objects.get(user=self.usuario.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.hoy = timezone.localdate()

    def _muestra(self, externo, dia, desde, hasta, cantidad, dispositivo=IPHONE):
        base = datetime(dia.year, dia.month, dia.day, tzinfo=GT)
        return {
            "external_id": externo,
            "inicio": (base + timedelta(hours=desde)).isoformat(),
            "fin": (base + timedelta(hours=hasta)).isoformat(),
            "cantidad": cantidad,
            "fuente_nombre": dispositivo["dispositivo_modelo"], **dispositivo,
        }

    def _sync(self, dia, pasos):
        r = self.client.post("/api/v1/sync", {
            "fecha": dia.isoformat(), "zona_horaria": "America/Guatemala",
            "sincronizado_en": (datetime.combine(dia, datetime.min.time(), tzinfo=GT) + timedelta(hours=23)).isoformat(),
            "app_version": "1.0.0", "pasos": pasos, "sesiones": [], "frecuencia_cardiaca": [],
        }, format="json")
        self.assertEqual(r.status_code, 200, r.content)
        return r.json()

    def test_la_pulsera_de_diez_horas_no_infla_el_dia(self):
        pasos = [self._muestra(f"i{h}", self.hoy, h, h + 0.5, 1200) for h in range(8, 18)]
        pasos.append(self._muestra("p", self.hoy, 8, 18, 11000, PULSERA))
        r = self._sync(self.hoy, pasos)
        self.assertEqual(r["pasos_totales_dia"], 12000)
        self.assertEqual(r["puntos_pasos"], 50)          # 12.000 pasos, no 21.800 (que daban 100)

    def test_una_muestra_que_cruza_la_medianoche_cuenta_en_los_dos_dias(self):
        ayer = self.hoy - timedelta(days=1)
        noche = self._muestra("noche", ayer, 22, 30, 8000)
        manana = self._sync(ayer, [noche])
        self.assertEqual(manana["pasos_totales_dia"], 2000)           # las 2 horas de ese día
        hoy = self._sync(self.hoy, [noche])
        self.assertEqual(hoy["pasos_totales_dia"], 6000)              # las 6 horas de este
        self.assertEqual(manana["pasos_totales_dia"] + hoy["pasos_totales_dia"], 8000)

    def test_repetir_el_sync_no_cambia_nada(self):
        pasos = [self._muestra("a", self.hoy, 8, 18, 5000, PULSERA), self._muestra("b", self.hoy, 9, 9.5, 1000)]
        primero = self._sync(self.hoy, pasos)
        segundo = self._sync(self.hoy, pasos)
        self.assertEqual(primero["pasos_totales_dia"], segundo["pasos_totales_dia"])
