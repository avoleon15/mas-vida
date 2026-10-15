"""Deja corriendo las corridas del objetivo semanal y de La Liga (hora de Guatemala).

  python manage.py programador            # se queda corriendo
  python manage.py programador --una-vez  # solo la puesta al día de arranque

Al arrancar se pone al día con las semanas pendientes (por si estuvo apagado el
martes) y después espera:
  - martes 00:00 -> cierre: fija el resultado de la semana y paga las monedas
    (el lunes queda para los datos atrasados del domingo)
  - martes 12:00 -> corrección: actualiza los acumulados, no paga ni reabre
  - día 2, 00:00 -> liga: cierra La Liga del mes anterior
    (el día 1 queda para los datos atrasados del último día)
  - día 9, 00:00 -> pago_liga: paga el podio (monedas y cupón) del mes cerrado

Pensado para correr como un servicio aparte (ver compose.yaml).
"""
import logging
import time

from django.core.management.base import BaseCommand
from django.db import connections
from django.utils import timezone

from services import goals, ligas, programador

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Corre el cierre semanal (martes 00:00), su corrección (martes 12:00), el cierre de La Liga (día 2) y el pago de su podio (día 9)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--una-vez",
            action="store_true",
            dest="una_vez",
            help="Solo hace la puesta al día de arranque y termina.",
        )

    def handle(self, *args, **opciones):
        hoy = timezone.localdate()
        cerradas = goals.ponerse_al_dia(hoy)
        if cerradas:
            for lunes, resumen in cerradas:
                self.stdout.write(f"Puesta al día: semana {lunes}: {resumen}")
        else:
            self.stdout.write("Puesta al día: no hay semanas pendientes.")
        for resumen in ligas.ponerse_al_dia(hoy):
            self.stdout.write(f"Puesta al día: La Liga {resumen['mes']}: {resumen}")
        for resumen in ligas.pagar_al_dia(hoy):
            self.stdout.write(f"Puesta al día: podio de La Liga {resumen['mes']}: {resumen}")

        proxima, tipo = programador.proxima_ejecucion(timezone.now())
        self.stdout.write(self.style.SUCCESS(
            f"Próxima corrida: {tipo} el {timezone.localtime(proxima):%Y-%m-%d %H:%M} (hora de Guatemala)"
        ))
        if opciones["una_vez"]:
            return

        def ejecutar_y_avisar(tipo, momento):
            # En producción los logs informativos no salen (DEBUG apagado); esto
            # sí, para que se vea en el log del servicio que la corrida ocurrió.
            resultado = programador.ejecutar(tipo, momento)
            self.stdout.write(
                f"[{timezone.localtime(momento):%Y-%m-%d %H:%M}] {tipo}: {resultado}"
            )
            siguiente, tipo_siguiente = programador.proxima_ejecucion(momento)
            self.stdout.write(
                f"Próxima corrida: {tipo_siguiente} el "
                f"{timezone.localtime(siguiente):%Y-%m-%d %H:%M} (hora de Guatemala)"
            )

        # Tras días de espera la conexión a la base ya no sirve: se cierra antes
        # de cada corrida y Django abre una nueva.
        programador.correr(
            ahora_fn=timezone.now,
            dormir_fn=time.sleep,
            ejecutar_fn=ejecutar_y_avisar,
            antes_de_ejecutar=connections.close_all,
        )
