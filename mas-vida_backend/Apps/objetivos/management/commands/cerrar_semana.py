"""Evalúa el objetivo de la semana que acaba de cerrar y paga las monedas.

Uso (hora de Guatemala):
  python manage.py cerrar_semana                  # lunes 00:00: fija y paga
  python manage.py cerrar_semana --correccion     # lunes 12:00: solo corrige acumulados
  python manage.py cerrar_semana --fecha 2026-09-28   # simular otro "hoy"
  python manage.py cerrar_semana --ponerse-al-dia     # cierra TODAS las pendientes

Sin `--ponerse-al-dia` evalúa solo la semana anterior a la de `--fecha`. Se
puede correr las veces que haga falta: no paga dos veces. Con
`--ponerse-al-dia` cierra todas las semanas terminadas que sigan sin cerrar
(hasta MAX_SEMANAS_ATRASADAS), útil después de un cron que falló.
"""
from datetime import date, timedelta

from django.core.management.base import BaseCommand, CommandError

from services import goals
from services.tiempo import hoy as hoy_guatemala
from services.tiempo import inicio_semana


class Command(BaseCommand):
    help = "Evalúa el objetivo semanal de la semana que acaba de cerrar."

    def add_arguments(self, parser):
        parser.add_argument(
            "--fecha",
            help="Día a tratar como 'hoy' (AAAA-MM-DD). Por defecto, hoy en Guatemala.",
        )
        parser.add_argument(
            "--ponerse-al-dia",
            action="store_true",
            dest="ponerse_al_dia",
            help="Cierra todas las semanas terminadas que sigan sin cerrar.",
        )
        parser.add_argument(
            "--correccion",
            action="store_true",
            help="Corrida de las 12:00: actualiza acumulados, no cambia cumplido ni paga.",
        )

    def handle(self, *args, **opciones):
        try:
            hoy = date.fromisoformat(opciones["fecha"]) if opciones["fecha"] else hoy_guatemala()
        except ValueError:
            raise CommandError("--fecha debe tener formato AAAA-MM-DD.")

        if opciones["ponerse_al_dia"]:
            if opciones["correccion"]:
                raise CommandError("--ponerse-al-dia no se combina con --correccion.")
            cerradas = goals.ponerse_al_dia(hoy)
            if not cerradas:
                self.stdout.write("No hay semanas pendientes.")
            for lunes, resumen in cerradas:
                self.stdout.write(self.style.SUCCESS(f"Semana {lunes} (cierre): {resumen}"))
            return

        lunes = inicio_semana(hoy) - timedelta(days=7)
        resumen = goals.cerrar_semana(lunes, hoy, correccion=opciones["correccion"])

        modo = "corrección" if opciones["correccion"] else "cierre"
        self.stdout.write(self.style.SUCCESS(
            f"Semana {lunes} ({modo}): {resumen}"
        ))
