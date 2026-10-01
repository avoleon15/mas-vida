"""Objetivo semanal — versión demo 1 (contrato técnico, 23 sep).

Un objetivo fijo e igual para todos: pasos totales de la semana + cantidad de
workouts, lunes 00:00 a domingo 23:59 en hora de Guatemala. Se cumple al
alcanzar las dos metas. Sin progresión entre objetivos: ProgresoObjetivoUsuario
y MetaPorPasosObjetivo quedan para cuando vuelva el diseño completo.

Las metas viven en ObjetivoSemanal y se editan a mano en el admin. Cada semana
nueva copia las de la anterior; la primera usa los valores de abajo.

Dos corridas el lunes (comando `cerrar_semana`):
- 00:00: fija `cumplido` de la semana que cerró y paga las monedas.
- 12:00 (`--correccion`): actualiza los acumulados con datos atrasados, pero
  ya no cambia `cumplido` ni paga nada. Un ciclo cerrado no se reabre.

Pasos y workouts salen de ResumenDiario, no de las muestras crudas: ahí ya
está resuelto qué dispositivo gana cada métrica, así que un entrenamiento
registrado por el reloj y por el teléfono cuenta una sola vez.
"""
from dataclasses import dataclass
from datetime import date, timedelta

from django.db import transaction
from django.db.models import Sum

from Apps.activities.models import ResumenDiario
from Apps.coins.models import MonedaLedger
from Apps.objetivos.models import CumplimientoSemanal, ObjetivoSemanal, Season
from Apps.users.models import Usuario
from services import monedas
from services.polizas import fecha_corte_sin_retroactivo
from services.tiempo import fin_semana, inicio_semana, numero_season, rango_season

# [PENDIENTE] metas definitivas del demo. Son las del ejemplo del contrato.
META_PASOS_INICIAL = 30_000
META_WORKOUTS_INICIAL = 1

# [PENDIENTE] ningún documento fija cuántas monedas paga cumplir el objetivo.
MONEDAS_POR_OBJETIVO = 20


@dataclass
class Progreso:
    pasos: int
    workouts: int
    objetivo: ObjetivoSemanal

    @property
    def cumplido(self) -> bool:
        return (
            self.pasos >= self.objetivo.meta_pasos
            and self.workouts >= self.objetivo.meta_workouts
        )


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
        },
    )
    return objetivo


def season_de(fecha: date) -> Season:
    """Season (trimestre) que contiene `fecha`; la crea si no existe."""
    inicio, fin = rango_season(fecha)
    season, _ = Season.objects.get_or_create(
        anio=fecha.year,
        numero=numero_season(fecha),
        defaults={"fecha_inicio": inicio, "fecha_fin": fin},
    )
    return season


def _totales(filas):
    datos = filas.aggregate(
        pasos=Sum("pasos_totales_dia"), workouts=Sum("workouts_cantidad")
    )
    return datos["pasos"] or 0, datos["workouts"] or 0


def progreso(usuario, objetivo: ObjetivoSemanal) -> Progreso:
    pasos, workouts = _totales(
        ResumenDiario.objects.filter(
            usuario=usuario,
            fecha__gte=objetivo.fecha_inicio,
            fecha__lte=objetivo.fecha_fin,
        )
    )
    return Progreso(pasos=pasos, workouts=workouts, objetivo=objetivo)


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
    return {f["usuario"]: (f["pasos"] or 0, f["workouts"] or 0) for f in filas}


def cerrar_semana(lunes: date, hoy: date, correccion: bool = False) -> dict:
    """Evalúa la semana que arranca en `lunes`, para todos los usuarios.

    Idempotente: correrla otra vez no paga dos veces, porque las monedas solo
    se pagan al crear la fila de CumplimientoSemanal de ese usuario y semana.
    """
    objetivo = objetivo_de_la_semana(lunes)
    if hoy <= objetivo.fecha_fin:
        raise ValueError("La semana todavía no terminó")

    usuarios = list(Usuario.objects.all())
    avance = _progreso_de_todos(usuarios, objetivo)
    resumen = {"evaluados": 0, "cumplidos": 0, "monedas_pagadas": 0, "actualizados": 0}

    for usuario in usuarios:
        pasos, workouts = avance.get(usuario.pk, (0, 0))
        progreso_usuario = Progreso(pasos=pasos, workouts=workouts, objetivo=objetivo)

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
                    "cumplido": progreso_usuario.cumplido,
                    "evaluado_en": hoy,
                },
            )
            if not creado:
                continue
            resumen["evaluados"] += 1
            if not progreso_usuario.cumplido:
                continue
            resumen["cumplidos"] += 1

            # Retroactivo denegado: lo anterior a la verificación no cuenta,
            # tampoco las monedas de una semana que cerró antes del corte.
            corte = fecha_corte_sin_retroactivo(usuario)
            if corte is not None and objetivo.fecha_fin < corte:
                continue

            pago = monedas.acreditar(
                usuario,
                MONEDAS_POR_OBJETIVO,
                MonedaLedger.Tipo.OBJETIVO_CUMPLIDO,
                fecha=hoy,
            )
            resumen["monedas_pagadas"] += pago.acreditadas

    # El objetivo de la semana que arranca queda fijado desde las 00:00.
    objetivo_de_la_semana(objetivo.fecha_fin + timedelta(days=1))
    return resumen
