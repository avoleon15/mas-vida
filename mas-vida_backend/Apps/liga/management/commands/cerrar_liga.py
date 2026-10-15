"""Cierra y paga La Liga a mano (lo normal es que lo haga el programador: cierra el día 2 y paga el 9).

  python manage.py cerrar_liga               # cierra los meses terminados y paga los que ya toca
  python manage.py cerrar_liga --mes 2026-10 # cierra ese mes (si ya pasó su margen de gracia) y lo paga si ya es el día 9

Es idempotente: un mes ya cerrado no se cierra otra vez y uno ya pagado no se paga otra vez.
"""
from datetime import date

from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from services import ligas


class Command(BaseCommand):
    help = "Cierra La Liga del mes que terminó y, desde el día 9, paga el podio."

    def add_arguments(self, parser):
        parser.add_argument("--mes", help="Mes a cerrar, AAAA-MM.")

    def handle(self, *args, mes=None, **opciones):
        hoy = timezone.localdate()
        if mes is None:
            cierres = ligas.ponerse_al_dia(hoy)
            pagos = ligas.pagar_al_dia(hoy)
            if not cierres and not pagos:
                self.stdout.write("No hay meses de La Liga pendientes de cerrar ni de pagar.")
            for resumen in cierres:
                self.stdout.write(f"La Liga {resumen['mes']}: {resumen}")
            for resumen in pagos:
                self.stdout.write(f"Podio de La Liga {resumen['mes']}: {resumen}")
            return

        try:
            inicio = date.fromisoformat(f"{mes}-01")
        except ValueError:
            raise CommandError("El mes va como AAAA-MM, por ejemplo 2026-10.")
        if inicio < ligas.PRIMER_MES:
            raise CommandError(f"La Liga arranca en {ligas.PRIMER_MES:%Y-%m}.")
        try:
            resumen = ligas.cerrar_la_liga(inicio, hoy)
        except ValueError as e:
            raise CommandError(str(e))
        if not resumen["cerrada"]:
            self.stdout.write(f"La Liga {mes} ya estaba cerrada.")
        else:
            self.stdout.write(f"La Liga {resumen['mes']}: {resumen}")

        if hoy < ligas.dia_de_pago(inicio):
            self.stdout.write(f"El podio se paga desde el {ligas.dia_de_pago(inicio)}.")
            return
        pago = ligas.pagar_la_liga(inicio, hoy)
        if not pago["pagada"]:
            self.stdout.write(f"El podio de {mes} ya estaba pagado: no se pagó nada.")
        else:
            self.stdout.write(f"Podio de La Liga {pago['mes']}: {pago}")
