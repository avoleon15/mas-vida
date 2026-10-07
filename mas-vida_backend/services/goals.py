"""Objetivo semanal (demo 1, con los cambios de la reunión del 2 oct 2026).

Dos componentes por semana, lunes 00:00 a domingo 23:59 en hora de Guatemala:
pasos totales de la semana y cantidad de workouts.
- CADA componente paga sus monedas por separado; la semana queda
  "completada" (`cumplido`) solo si se cumplen los dos.
- La meta de pasos depende del rango de edad del usuario (MetaPasosPorEdad),
  medida el lunes de esa semana. La de workouts es igual para todos.
- Sin progresión entre objetivos: ProgresoObjetivoUsuario y
  MetaPorPasosObjetivo quedan para cuando vuelva el diseño completo.

La meta de workouts y las monedas de cada componente viven en ObjetivoSemanal
y se editan a mano en el admin; cada semana nueva copia las de la anterior.

Dos corridas el martes (comando `cerrar_semana`):
- 00:00: fija `cumplido` de la semana que terminó el domingo y paga las
  monedas. Espera todo el lunes (DIAS_DE_GRACIA) para que lleguen los datos
  atrasados: un domingo que se sincroniza el lunes todavía cuenta.
- 12:00 (`--correccion`): actualiza los acumulados con datos atrasados, pero
  ya no cambia `cumplido` ni paga nada. Un ciclo cerrado no se reabre.

Pasos y workouts salen de ResumenDiario, no de las muestras crudas: ahí ya
está resuelto qué dispositivo gana cada métrica, así que un entrenamiento
registrado por el reloj y por el teléfono cuenta una sola vez.
"""
import logging
from dataclasses import dataclass
from datetime import date, timedelta

from django.db import transaction
from django.db.models import Max, Min, Sum

from Apps.activities.models import ResumenDiario
from Apps.coins.models import MonedaLedger
from Apps.objetivos.models import CumplimientoSemanal, MetaPasosPorEdad, ObjetivoSemanal, Season
from Apps.users.models import Usuario
from services import monedas, patrocinios
from services.daily_scoring import fecha_nacimiento_efectiva
from services.hearth_rate import calculate_age
from services.polizas import cortes_de_retroactivo, fecha_corte_sin_retroactivo
from services.tiempo import (
    anio_season,
    fin_semana,
    inicio_semana,
    lunes_de_la_season,
    numero_semana_en_season,
    numero_season,
    rango_season,
)

logger = logging.getLogger(__name__)

# [PENDIENTE] metas definitivas del demo. Son las del ejemplo del contrato.
META_PASOS_INICIAL = 30_000
META_WORKOUTS_INICIAL = 1

# [PENDIENTE] montos provisionales (reunión del 2 oct 2026): 5 por cada
# componente. Se editan semana por semana en ObjetivoSemanal.
MONEDAS_POR_COMPONENTE_INICIAL = 5

# Días después del domingo que se esperan antes de cerrar una semana: con 1, se
# cierra el martes 00:00 y los datos atrasados tienen todo el lunes para llegar
# (decidido 3 oct 2026; StepBet da 24 h, Discovery Vitality 48 h). Vale para
# cualquier cierre, también para ponerse al día: un servidor que arranca un
# lunes no cierra la semana anterior antes de tiempo.
DIAS_DE_GRACIA = 1

# Cuántas semanas atrasadas se cierran como máximo al ponerse al día. Sin tope,
# la primera vez que corra con datos viejos pagaría monedas de hace meses.
MAX_SEMANAS_ATRASADAS = 4


@dataclass
class Progreso:
    pasos: int
    workouts: int
    objetivo: ObjetivoSemanal
    # Meta de pasos de ESTE usuario (por su edad). Sin ella se usa la del objetivo.
    meta_pasos: int | None = None

    @property
    def meta_pasos_efectiva(self) -> int:
        return self.meta_pasos if self.meta_pasos is not None else self.objetivo.meta_pasos

    @property
    def cumplio_pasos(self) -> bool:
        return self.pasos >= self.meta_pasos_efectiva

    @property
    def cumplio_workouts(self) -> bool:
        return self.workouts >= self.objetivo.meta_workouts

    @property
    def completada(self) -> bool:
        """La semana queda completada solo con los dos componentes."""
        return self.cumplio_pasos and self.cumplio_workouts

    @property
    def cumplido(self) -> bool:
        # Nombre histórico: significa semana completada.
        return self.completada


def meta_pasos_para_edad(edad: int, respaldo: int | None = None) -> int:
    """Meta semanal de pasos del rango de edad (tabla MetaPasosPorEdad).

    Gana la fila con el `edad_desde` más alto que no pase la edad. Una edad menor
    que la primera fila usa la primera. Si la tabla está vacía, `respaldo`.
    """
    fila = (
        MetaPasosPorEdad.objects.filter(edad_desde__lte=edad).order_by("-edad_desde").first()
        or MetaPasosPorEdad.objects.order_by("edad_desde").first()
    )
    if fila is not None:
        return fila.meta_pasos
    if respaldo is None:
        raise ValueError("No hay metas de pasos por edad cargadas")
    return respaldo


def edad_en(usuario, fecha: date) -> int:
    """Edad del usuario en `fecha`, con la fecha de nacimiento que manda.

    La confirmada por la aseguradora si hay póliza verificada; si no, la del
    registro (la misma regla que usan los puntos).
    """
    return calculate_age(fecha_nacimiento_efectiva(usuario, fecha), fecha)


def meta_pasos_de(usuario, objetivo: ObjetivoSemanal) -> int:
    """Meta de pasos del usuario esa semana, con su edad del lunes."""
    return meta_pasos_para_edad(edad_en(usuario, objetivo.fecha_inicio), objetivo.meta_pasos)


def objetivo_de_la_semana(fecha: date) -> ObjetivoSemanal:
    """Objetivo de la semana que contiene `fecha`; lo crea si todavía no existe."""
    lunes = inicio_semana(fecha)
    existente = ObjetivoSemanal.objects.filter(fecha_inicio=lunes).first()
    if existente:
        return existente

    anterior = (
        ObjetivoSemanal.objects
        .filter(fecha_inicio__lt=lunes)
        .order_by("-fecha_inicio")
        .first()
    )
    objetivo, _ = ObjetivoSemanal.objects.get_or_create(
        fecha_inicio=lunes,
        defaults={
            "fecha_fin": fin_semana(lunes),
            "meta_pasos": anterior.meta_pasos if anterior else META_PASOS_INICIAL,
            "meta_workouts": anterior.meta_workouts if anterior else META_WORKOUTS_INICIAL,
            "monedas_pasos": (
                anterior.monedas_pasos if anterior else MONEDAS_POR_COMPONENTE_INICIAL
            ),
            "monedas_workouts": (
                anterior.monedas_workouts if anterior else MONEDAS_POR_COMPONENTE_INICIAL
            ),
        },
    )
    return objetivo


def season_de(fecha: date) -> Season:
    """Season (13 semanas ISO) que contiene `fecha`; la crea si no existe.

    Si la fila ya existía con otras fechas (se guardó con la regla vieja de
    trimestres de calendario), se corrige: las fechas las manda siempre el
    cálculo, no lo que haya quedado guardado.
    """
    inicio, fin = rango_season(fecha)
    season, creada = Season.objects.get_or_create(
        anio=anio_season(fecha),
        numero=numero_season(fecha),
        defaults={"fecha_inicio": inicio, "fecha_fin": fin},
    )
    if not creada and (season.fecha_inicio, season.fecha_fin) != (inicio, fin):
        season.fecha_inicio, season.fecha_fin = inicio, fin
        season.save(update_fields=["fecha_inicio", "fecha_fin"])
    return season


def _totales(filas):
    datos = filas.aggregate(
        pasos=Sum("pasos_totales_dia"), workouts=Sum("workouts_cantidad")
    )
    return datos["pasos"] or 0, datos["workouts"] or 0


def progreso(usuario, objetivo: ObjetivoSemanal) -> Progreso:
    # Lo anterior a la verificación, si se denegó el retroactivo, no cuenta para la meta.
    corte = fecha_corte_sin_retroactivo(usuario)
    desde = max(objetivo.fecha_inicio, corte) if corte is not None else objetivo.fecha_inicio
    pasos, workouts = _totales(
        ResumenDiario.objects.filter(
            usuario=usuario,
            fecha__gte=desde,
            fecha__lte=objetivo.fecha_fin,
        )
    )
    return Progreso(
        pasos=pasos, workouts=workouts, objetivo=objetivo,
        meta_pasos=meta_pasos_de(usuario, objetivo),
    )


def _progreso_de_todos(usuarios, objetivo: ObjetivoSemanal) -> dict[int, tuple[int, int]]:
    filas = (
        ResumenDiario.objects
        .filter(
            usuario__in=usuarios,
            fecha__gte=objetivo.fecha_inicio,
            fecha__lte=objetivo.fecha_fin,
        )
        .values("usuario")
        .annotate(pasos=Sum("pasos_totales_dia"), workouts=Sum("workouts_cantidad"))
    )
    avance = {f["usuario"]: (f["pasos"] or 0, f["workouts"] or 0) for f in filas}

    # Quien tiene el retroactivo denegado: los días anteriores a su verificación no
    # cuentan para la meta (los de la semana que cruza la verificación tampoco).
    for pk, corte in cortes_de_retroactivo(u.pk for u in usuarios).items():
        if corte <= objetivo.fecha_inicio:
            continue
        avance[pk] = (0, 0) if corte > objetivo.fecha_fin else _totales(
            ResumenDiario.objects.filter(usuario_id=pk, fecha__gte=corte, fecha__lte=objetivo.fecha_fin)
        )
    return avance


def primer_dia_de_cierre(lunes: date) -> date:
    """Desde qué día se puede cerrar la semana que arranca en `lunes`: el
    martes siguiente (el domingo + 1 + DIAS_DE_GRACIA)."""
    return fin_semana(lunes) + timedelta(days=1 + DIAS_DE_GRACIA)


def cerrar_semana(lunes: date, hoy: date, correccion: bool = False) -> dict:
    """Evalúa la semana que arranca en `lunes`, para todos los usuarios.

    Idempotente: correrla otra vez no paga dos veces, porque las monedas solo
    se pagan al crear la fila de CumplimientoSemanal de ese usuario y semana.
    """
    objetivo = objetivo_de_la_semana(lunes)
    if hoy <= objetivo.fecha_fin:
        raise ValueError("La semana todavía no terminó")
    if hoy < primer_dia_de_cierre(lunes):
        raise ValueError(
            "La semana sigue en su margen de gracia: se cierra el "
            f"{primer_dia_de_cierre(lunes).isoformat()}"
        )

    # Quien dio de baja su cuenta ya no tiene semana que cerrar.
    usuarios = list(Usuario.objects.filter(dado_de_baja_en__isnull=True))
    avance = _progreso_de_todos(usuarios, objetivo)
    patrocinio = patrocinios.de_semana(lunes)
    numero_en_la_season = numero_semana_en_season(lunes)
    # cumplidos = semanas COMPLETADAS (los dos componentes); los pagos cuentan aparte.
    resumen = {
        "evaluados": 0, "cumplidos": 0, "pagos_pasos": 0, "pagos_workouts": 0,
        "monedas_pagadas": 0, "actualizados": 0, "cupones": 0,
    }

    for usuario in usuarios:
        pasos, workouts = avance.get(usuario.pk, (0, 0))
        progreso_usuario = Progreso(
            pasos=pasos, workouts=workouts, objetivo=objetivo,
            meta_pasos=meta_pasos_de(usuario, objetivo),
        )

        if correccion:
            resumen["actualizados"] += CumplimientoSemanal.objects.filter(
                usuario=usuario, objetivo_semanal=objetivo
            ).update(pasos_semanales=pasos, workouts_acumulados=workouts)
            continue

        with transaction.atomic():
            _, creado = CumplimientoSemanal.objects.get_or_create(
                usuario=usuario,
                objetivo_semanal=objetivo,
                defaults={
                    "pasos_semanales": pasos,
                    "workouts_acumulados": workouts,
                    "meta_pasos": progreso_usuario.meta_pasos_efectiva,
                    "cumplio_pasos": progreso_usuario.cumplio_pasos,
                    "cumplio_workouts": progreso_usuario.cumplio_workouts,
                    "cumplido": progreso_usuario.completada,
                    "evaluado_en": hoy,
                },
            )
            if not creado:
                continue
            resumen["evaluados"] += 1
            resumen["cumplidos"] += progreso_usuario.completada

            # Retroactivo denegado: lo anterior a la verificación no cuenta,
            # tampoco las monedas de una semana que cerró antes del corte.
            corte = fecha_corte_sin_retroactivo(usuario)
            if corte is not None and objetivo.fecha_fin < corte:
                continue

            # Cada componente paga lo suyo, aunque el otro no se cumpla.
            for cumplio, cantidad, clave in (
                (progreso_usuario.cumplio_pasos, objetivo.monedas_pasos, "pagos_pasos"),
                (progreso_usuario.cumplio_workouts, objetivo.monedas_workouts, "pagos_workouts"),
            ):
                if not cumplio or cantidad == 0:
                    continue
                pago = monedas.acreditar(
                    usuario, cantidad, MonedaLedger.Tipo.OBJETIVO_CUMPLIDO, fecha=hoy,
                )
                resumen[clave] += 1
                resumen["monedas_pagadas"] += pago.acreditadas

            # Semana patrocinada: el cupón de la marca es ADEMÁS de las monedas
            # y pide completar la semana (los dos componentes).
            if patrocinio is not None and progreso_usuario.completada:
                cupon = patrocinios.premiar_semana(usuario, patrocinio, numero_en_la_season)
                resumen["cupones"] += cupon is not None

    # El objetivo de la semana siguiente ya está fijado desde el lunes 00:00 (se
    # crea al pedirlo); esto solo asegura que exista.
    objetivo_de_la_semana(objetivo.fecha_fin + timedelta(days=1))
    return resumen


def semanas_pendientes(hoy: date) -> list[date]:
    """Lunes de las semanas que ya se pueden cerrar y todavía no se cerraron.

    "Cerrada" = existe al menos un CumplimientoSemanal de esa semana. "Se puede
    cerrar" = ya pasó su margen de gracia (`primer_dia_de_cierre`): la semana en
    curso nunca entra, y el lunes la que terminó el domingo tampoco, porque
    todavía espera datos atrasados. Si nunca se cerró ninguna, se empieza por la
    primera semana con datos (o con objetivo), sin pasar de
    MAX_SEMANAS_ATRASADAS hacia atrás.
    """
    ultima_cerrable = inicio_semana(hoy - timedelta(days=DIAS_DE_GRACIA)) - timedelta(days=7)

    ultima_cerrada = ObjetivoSemanal.objects.filter(
        cumplimientosemanal__isnull=False
    ).aggregate(m=Max("fecha_inicio"))["m"]

    if ultima_cerrada is not None:
        primera = ultima_cerrada + timedelta(days=7)
    else:
        candidatas = []
        primer_objetivo = ObjetivoSemanal.objects.aggregate(m=Min("fecha_inicio"))["m"]
        primer_dato = ResumenDiario.objects.aggregate(m=Min("fecha"))["m"]
        if primer_objetivo is not None:
            candidatas.append(primer_objetivo)
        if primer_dato is not None:
            candidatas.append(inicio_semana(primer_dato))
        if not candidatas:
            return []
        primera = min(candidatas)

    mas_vieja_permitida = ultima_cerrable - timedelta(days=7 * (MAX_SEMANAS_ATRASADAS - 1))
    if primera < mas_vieja_permitida:
        logger.warning(
            "Se omiten las semanas anteriores al %s: pasan del tope de %d semanas atrasadas",
            mas_vieja_permitida, MAX_SEMANAS_ATRASADAS,
        )
        primera = mas_vieja_permitida

    semanas = []
    lunes = primera
    while lunes <= ultima_cerrable:
        semanas.append(lunes)
        lunes += timedelta(days=7)
    return semanas


def ponerse_al_dia(hoy: date) -> list[tuple[date, dict]]:
    """Cierra todas las semanas pendientes, de la más vieja a la más nueva.

    Es lo que salva a un cron que falló un lunes: la siguiente corrida cierra
    también la semana que se quedó sin cerrar. Idempotente.
    """
    return [(lunes, cerrar_semana(lunes, hoy)) for lunes in semanas_pendientes(hoy)]


# Estado de cada semana en la vista de la season ("battle pass").
COMPLETADA = "completada"      # los dos componentes cumplidos
PARCIAL = "parcial"            # solo uno
NO_CUMPLIDA = "no_cumplida"    # ninguno
EN_CURSO = "en_curso"
# La semana terminó el domingo pero sigue en su margen de gracia (el lunes): todavía
# pueden llegar datos atrasados, así que no se dice "no cumplida" ni "completada"
# hasta el cierre del martes. Las cifras van en vivo, como provisionales.
EN_REVISION = "en_revision"
FUTURA = "futura"


@dataclass
class SemanaDeSeason:
    numero: int                    # 1 a 13 (o 14) dentro de la season
    objetivo: ObjetivoSemanal
    estado: str
    meta_pasos: int                # la de este usuario, por su edad ese lunes
    pasos: int | None = None       # None en las semanas futuras
    workouts: int | None = None
    cumplio_pasos: bool | None = None
    cumplio_workouts: bool | None = None


def _estado_por_componentes(cumplio_pasos: bool, cumplio_workouts: bool) -> str:
    if cumplio_pasos and cumplio_workouts:
        return COMPLETADA
    if cumplio_pasos or cumplio_workouts:
        return PARCIAL
    return NO_CUMPLIDA


def semanas_de_la_season(usuario, hoy: date) -> list[SemanaDeSeason]:
    """Todas las semanas de la season de `hoy`, con lo que hizo el usuario.

    - Semanas cerradas: lo que quedó guardado al cerrarlas (CumplimientoSemanal).
    - La que terminó el domingo, mientras dura su margen de gracia (el lunes):
      `en_revision`, con las cifras en vivo.
    - Una semana que ya pasó su margen y sigue sin cerrar (el cierre falló): se
      calcula en vivo.
    - La semana en curso: en vivo.
    - Las futuras: solo metas y monedas. Su ObjetivoSemanal se crea (copiando la
      semana anterior) para que se pueda editar en el admin antes de que llegue.
    """
    lunes_hoy = inicio_semana(hoy)
    todos_los_lunes = lunes_de_la_season(hoy)
    cerradas = {
        c.objetivo_semanal.fecha_inicio: c
        for c in CumplimientoSemanal.objects.filter(
            usuario=usuario, objetivo_semanal__fecha_inicio__in=todos_los_lunes,
        ).select_related("objetivo_semanal")
    }

    semanas = []
    for numero, lunes in enumerate(todos_los_lunes, start=1):
        objetivo = objetivo_de_la_semana(lunes)

        if lunes > lunes_hoy:
            semanas.append(SemanaDeSeason(
                numero=numero, objetivo=objetivo, estado=FUTURA,
                meta_pasos=meta_pasos_de(usuario, objetivo),
            ))
            continue

        cerrada = cerradas.get(lunes)
        if cerrada is not None and lunes < lunes_hoy:
            semanas.append(SemanaDeSeason(
                numero=numero, objetivo=objetivo,
                estado=_estado_por_componentes(cerrada.cumplio_pasos, cerrada.cumplio_workouts),
                meta_pasos=cerrada.meta_pasos or meta_pasos_de(usuario, objetivo),
                pasos=cerrada.pasos_semanales, workouts=cerrada.workouts_acumulados,
                cumplio_pasos=cerrada.cumplio_pasos, cumplio_workouts=cerrada.cumplio_workouts,
            ))
            continue

        avance = progreso(usuario, objetivo)
        if lunes == lunes_hoy:
            estado = EN_CURSO
        elif hoy < primer_dia_de_cierre(lunes):
            estado = EN_REVISION
        else:
            estado = _estado_por_componentes(avance.cumplio_pasos, avance.cumplio_workouts)
        semanas.append(SemanaDeSeason(
            numero=numero, objetivo=objetivo, estado=estado,
            meta_pasos=avance.meta_pasos_efectiva,
            pasos=avance.pasos, workouts=avance.workouts,
            cumplio_pasos=avance.cumplio_pasos, cumplio_workouts=avance.cumplio_workouts,
        ))
    return semanas
