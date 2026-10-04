"""La Liga y Tus Ligas: rankings mensuales por puntos.

Reglas (contrato-tecnico.md, "La Liga y Tus Ligas"):
- Las dos compiten por los PUNTOS del mes (día 1 al último, hora de
  Guatemala), los mismos que dan el cashback: la suma del ledger de puntos,
  con el tope diario, el bono 60+ y las correcciones.
- Desempate: primero más pasos en el mes (suma de `pasos_totales_dia`) y, si
  también empatan, más workouts (suma de `workouts_cantidad`; decidido el 3 oct
  2026). Los pasos y los workouts de los demás nunca salen del servidor: solo
  ordenan.
- Empate total (mismos puntos, pasos y workouts): comparten el puesto, y el
  siguiente se salta (1, 1, 3). Si los dos quedan en el podio, cada uno se
  lleva las monedas de ese puesto. [PENDIENTE] provisional (3 oct 2026).
- La Liga: un solo grupo con todos los usuarios con póliza verificada. Al
  cerrar el mes, los 3 primeros ganan monedas (PremioPodioLiga). Para ganar
  hay que tener al menos 1 punto en el mes.
- El cierre espera el mismo margen de gracia que la semana
  (`goals.DIAS_DE_GRACIA`, 1 día): el mes se cierra el día 2 a las 00:00, así
  lo caminado el último día y sincronizado el día 1 todavía cuenta.
- Tus Ligas: grupos que arma el usuario, con o sin póliza, sin premios. Se
  entra con un código y se puede salir cuando se quiera. De La Liga no se sale.
"""
import secrets
from dataclasses import dataclass
from datetime import date, timedelta

from django.core.exceptions import ObjectDoesNotExist
from django.db import transaction
from django.db.models import Sum

from Apps.activities.models import ResumenDiario
from Apps.coins.models import MonedaLedger
from Apps.liga.models import (
    DesgloseLigaMensual,
    LigaAmigos,
    LigaMensual,
    MiembroLigaAmigos,
    PremioPodioLiga,
)
from Apps.poincs.models import Ledger
from Apps.users.models import Usuario
from services import monedas
from services.goals import DIAS_DE_GRACIA
from services.polizas import VERIFICADA

# La Liga arranca en octubre de 2026: el primer cierre corre el 2 nov 2026.
# Los meses anteriores nunca se cierran (no se pagan monedas retroactivas).
PRIMER_MES = date(2026, 10, 1)

ID_LA_LIGA = "la-liga"
NOMBRE_LA_LIGA = "La Liga"

SUBIDA = "subida"
BAJADA = "bajada"
IGUAL = "igual"

LARGO_NOMBRE_LIGA = 60

# Sin O/0 ni I/1: el código se dicta o se copia a mano.
_ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
LARGO_CODIGO = 6


class CodigoInvalido(Exception):
    """Ningún grupo tiene ese código."""


class NombreInvalido(ValueError):
    pass


class LaLigaNoSeSale(Exception):
    """La Liga es un solo grupo automático: no se abandona."""


class NoEresMiembro(Exception):
    """El grupo no existe o el usuario no está en él."""


# --- fechas ------------------------------------------------------------------

def rango_mes(fecha: date) -> tuple[date, date]:
    """Primer y último día del mes de `fecha`."""
    inicio = fecha.replace(day=1)
    siguiente = (inicio + timedelta(days=32)).replace(day=1)
    return inicio, siguiente - timedelta(days=1)


def dia_de_cierre(mes: date) -> date:
    """Desde qué día se puede cerrar el mes de `mes`: el día 2 del siguiente.

    El día 1 completo es el margen de gracia para los datos atrasados del
    último día (lo mismo que el lunes para la semana).
    """
    return rango_mes(mes)[1] + timedelta(days=1 + DIAS_DE_GRACIA)


# --- la tabla ------------------------------------------------------------------

@dataclass
class Fila:
    usuario_pk: int
    puntos: int
    pasos: int
    workouts: int
    posicion: int


def tabla(usuario_pks, inicio: date, hasta: date) -> list[Fila]:
    """Ranking de `usuario_pks` con lo acumulado de `inicio` a `hasta` (inclusive).

    Por puntos; a igualdad, por pasos; a igualdad, por workouts; a igualdad de
    los tres, comparten el puesto. El orden entre empatados totales es estable
    (por pk) para que la lista no baile entre pedidos.
    """
    pks = list(usuario_pks)
    if not pks:
        return []
    puntos = dict(
        Ledger.objects.filter(usuario__in=pks, fecha__range=(inicio, hasta))
        .values("usuario").annotate(total=Sum("puntos")).values_list("usuario", "total")
    )
    pasos = dict(
        ResumenDiario.objects.filter(usuario__in=pks, fecha__range=(inicio, hasta))
        .values("usuario").annotate(total=Sum("pasos_totales_dia"))
        .values_list("usuario", "total")
    )
    # `workouts_cantidad` es nulo en los días sin dato: no suma.
    workouts = dict(
        ResumenDiario.objects.filter(usuario__in=pks, fecha__range=(inicio, hasta))
        .values("usuario").annotate(total=Sum("workouts_cantidad"))
        .values_list("usuario", "total")
    )
    orden = sorted(
        pks,
        key=lambda pk: (
            -(puntos.get(pk) or 0), -(pasos.get(pk) or 0), -(workouts.get(pk) or 0), pk,
        ),
    )

    filas = []
    for indice, pk in enumerate(orden):
        fila = Fila(
            pk, puntos.get(pk) or 0, pasos.get(pk) or 0, workouts.get(pk) or 0, indice + 1,
        )
        anterior = filas[-1] if filas else None
        if anterior and (anterior.puntos, anterior.pasos, anterior.workouts) == (
            fila.puntos, fila.pasos, fila.workouts,
        ):
            fila.posicion = anterior.posicion
        filas.append(fila)
    return filas


def tendencias(filas: list[Fila], inicio: date, hoy: date) -> dict[int, str]:
    """Cómo se movió cada uno respecto de la tabla de ayer (`igual` el día 1).

    `filas` es la tabla de hoy (la de `tabla(..., inicio, hoy)`).
    """
    if hoy <= inicio:
        return {f.usuario_pk: IGUAL for f in filas}
    ayer = {
        f.usuario_pk: f.posicion
        for f in tabla([f.usuario_pk for f in filas], inicio, hoy - timedelta(days=1))
    }
    resultado = {}
    for fila in filas:
        antes = ayer.get(fila.usuario_pk, fila.posicion)
        resultado[fila.usuario_pk] = (
            SUBIDA if fila.posicion < antes else BAJADA if fila.posicion > antes else IGUAL
        )
    return resultado


def nombre_publico(usuario: Usuario) -> str:
    """El nombre que ven los demás. Nunca el `username`: es la mitad del login.

    Con póliza verificada, nombre e inicial del apellido de la aseguradora
    ("Ana M."). Si no, "Usuario 4F2A", sacado del id público.
    """
    try:
        poliza = usuario.poliza
    except ObjectDoesNotExist:
        poliza = None
    if poliza and poliza.estado_verificacion == VERIFICADA and (poliza.nombre or "").strip():
        nombre = poliza.nombre.strip().split()[0].capitalize()
        apellido = (poliza.apellido or "").strip()
        return f"{nombre} {apellido[0].upper()}." if apellido else nombre
    return f"Usuario {usuario.usuario_id.replace('-', '')[:4].upper()}"


def usuarios(pks) -> dict[int, Usuario]:
    return {u.pk: u for u in Usuario.objects.filter(pk__in=list(pks)).select_related("poliza")}


# --- La Liga -------------------------------------------------------------------

def participantes_la_liga():
    """Todos los usuarios con póliza verificada: un solo grupo."""
    return Usuario.objects.filter(poliza__estado_verificacion=VERIFICADA)


def puede_entrar_a_la_liga(usuario) -> bool:
    return participantes_la_liga().filter(pk=usuario.pk).exists()


def premios_podio() -> list[int]:
    """Monedas del 1.º, 2.º y 3.º, en ese orden."""
    return list(PremioPodioLiga.objects.order_by("puesto").values_list("monedas", flat=True))


def cerrar_la_liga(mes: date, hoy: date) -> dict:
    """Cierra La Liga del mes de `mes`: guarda la tabla final y paga el podio.

    Una sola vez: si ya está cerrada no hace nada (idempotente, y seguro con
    dos instancias del programador). Las monedas se pagan con fecha `hoy`, así
    que cuentan en la season de ese día.
    """
    inicio, fin = rango_mes(mes)
    if hoy < dia_de_cierre(mes):
        raise ValueError(
            f"El mes {inicio:%Y-%m} se cierra desde el {dia_de_cierre(mes)}"
            " (terminó o está en su margen de gracia)"
        )

    resumen = {"mes": inicio.isoformat(), "cerrada": False, "participantes": 0, "monedas_pagadas": 0}
    with transaction.atomic():
        liga, _ = LigaMensual.objects.select_for_update().get_or_create(mes=inicio)
        if liga.cerrada_en is not None:
            return resumen

        filas = tabla(participantes_la_liga().values_list("pk", flat=True), inicio, fin)
        podio = premios_podio()
        por_pk = usuarios(f.usuario_pk for f in filas)
        for fila in filas:
            gana = (
                podio[fila.posicion - 1]
                if fila.puntos > 0 and fila.posicion <= len(podio) else 0
            )
            DesgloseLigaMensual.objects.create(
                usuario=por_pk[fila.usuario_pk],
                liga_mensual=liga,
                pasos_acumulados_mes=fila.pasos,
                workouts_acumulados_mes=fila.workouts,
                puntos_mes=fila.puntos,
                posicion_final=fila.posicion,
                monedas=gana,
            )
            if gana:
                monedas.acreditar(por_pk[fila.usuario_pk], gana, MonedaLedger.Tipo.LIGA_MENSUAL, fecha=hoy)
                resumen["monedas_pagadas"] += gana

        liga.total_participantes = len(filas)
        liga.cerrada_en = hoy
        liga.save(update_fields=["total_participantes", "cerrada_en"])
    resumen.update(cerrada=True, participantes=len(filas))
    return resumen


def ponerse_al_dia(hoy: date) -> list[dict]:
    """Cierra los meses de La Liga que ya pasaron su margen de gracia y sigan abiertos."""
    resultados = []
    mes = PRIMER_MES
    while dia_de_cierre(mes) <= hoy:
        if not LigaMensual.objects.filter(mes=mes, cerrada_en__isnull=False).exists():
            resultados.append(cerrar_la_liga(mes, hoy))
        mes = rango_mes(mes)[1] + timedelta(days=1)
    return resultados


# --- Tus Ligas -----------------------------------------------------------------

def _codigo() -> str:
    return "".join(secrets.choice(_ALFABETO) for _ in range(LARGO_CODIGO))


def crear_liga(usuario, nombre: str, hoy: date) -> LigaAmigos:
    """Crea un grupo de Tus Ligas con su código; quien lo crea queda adentro."""
    nombre = nombre.strip() if isinstance(nombre, str) else ""
    if not nombre or len(nombre) > LARGO_NOMBRE_LIGA:
        raise NombreInvalido(f"El nombre tiene que tener de 1 a {LARGO_NOMBRE_LIGA} caracteres")
    codigo = _codigo()
    while LigaAmigos.objects.filter(codigo_invitacion=codigo).exists():
        codigo = _codigo()
    with transaction.atomic():
        liga = LigaAmigos.objects.create(
            creador_usuario=usuario, nombre=nombre, mes=rango_mes(hoy)[0], codigo_invitacion=codigo,
        )
        MiembroLigaAmigos.objects.create(
            usuario=usuario, liga_amigos=liga, pasos_acumulados_mes=0, fecha_union=hoy,
        )
    return liga


def unirse(usuario, codigo: str, hoy: date) -> LigaAmigos:
    """Entra al grupo con ese código. Si ya estaba adentro, no pasa nada."""
    codigo = codigo.strip().upper() if isinstance(codigo, str) else ""
    liga = LigaAmigos.objects.filter(codigo_invitacion=codigo).first() if codigo else None
    if liga is None:
        raise CodigoInvalido()
    MiembroLigaAmigos.objects.get_or_create(
        usuario=usuario, liga_amigos=liga,
        defaults={"pasos_acumulados_mes": 0, "fecha_union": hoy},
    )
    return liga


def salir(usuario, liga_id) -> bool:
    """Saca al usuario de un grupo de Tus Ligas.

    Los demás siguen; si era el último miembro, el grupo se borra (y su código
    queda libre). Quien creó el grupo también puede salir: no se le pasa el
    grupo a nadie. Lanza LaLigaNoSeSale para La Liga y NoEresMiembro si el
    grupo no existe o el usuario no está adentro. Devuelve True si el grupo
    se borró.
    """
    if liga_id == ID_LA_LIGA:
        raise LaLigaNoSeSale()
    if not (isinstance(liga_id, str) and liga_id.isdigit()):
        raise NoEresMiembro()

    with transaction.atomic():
        # Se bloquea el grupo para que dos salidas a la vez no dejen uno vacío
        # sin borrar.
        liga = LigaAmigos.objects.select_for_update().filter(pk=int(liga_id)).first()
        membresia = (
            MiembroLigaAmigos.objects.filter(liga_amigos=liga, usuario=usuario).first()
            if liga else None
        )
        if membresia is None:
            raise NoEresMiembro()
        membresia.delete()
        if MiembroLigaAmigos.objects.filter(liga_amigos=liga).exists():
            return False
        liga.delete()
        return True


def ligas_de(usuario) -> list[LigaAmigos]:
    return list(
        LigaAmigos.objects.filter(miembroligaamigos__usuario=usuario).distinct().order_by("pk")
    )


def miembros(liga: LigaAmigos) -> list[int]:
    return list(MiembroLigaAmigos.objects.filter(liga_amigos=liga).values_list("usuario", flat=True))
