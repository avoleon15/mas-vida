"""Carga el registro SIMULADO de la aseguradora desde un CSV.

Uso:  python manage.py cargar_registro_aseguradora <ruta.csv>

Crea las pólizas que no existen y actualiza las que ya están (se identifican
por numero_poliza), así que se puede correr las veces que haga falta. Es todo
o nada: si una fila tiene un error no se guarda ninguna. Solo para pruebas.
"""
import csv
from datetime import date
from decimal import Decimal, InvalidOperation

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from Apps.policies.models import RegistroAseguradora

COLUMNAS = [
    "numero_poliza", "aseguradora", "nombre", "apellido", "fecha_nacimiento",
    "plan", "prima_anual_gtq", "deducible_gtq", "coaseguro_pct", "red",
    "vigencia_inicio", "vigencia_fin", "estado",
]


class Command(BaseCommand):
    help = "Carga o actualiza el registro simulado de la aseguradora desde un CSV."

    def add_arguments(self, parser):
        parser.add_argument("ruta", help="Ruta del archivo CSV")

    def handle(self, *args, **options):
        try:
            # utf-8-sig: tolera el BOM que agrega Excel al guardar como CSV.
            with open(options["ruta"], newline="", encoding="utf-8-sig") as archivo:
                filas = list(csv.DictReader(archivo))
        except OSError as error:
            raise CommandError(f"No se pudo leer el archivo: {error}")

        if not filas:
            raise CommandError("El CSV no tiene filas.")
        faltan = [c for c in COLUMNAS if c not in filas[0]]
        if faltan:
            raise CommandError(f"Faltan columnas en el CSV: {', '.join(faltan)}")

        creadas = actualizadas = 0
        with transaction.atomic():
            for numero, fila in enumerate(filas, start=2):  # la 1 es el encabezado
                try:
                    datos = self._convertir(fila)
                except (ValueError, InvalidOperation) as error:
                    raise CommandError(f"Fila {numero} ({fila.get('numero_poliza')}): {error}")

                _, creada = RegistroAseguradora.objects.update_or_create(
                    numero_poliza=datos.pop("numero_poliza"),
                    defaults=datos,
                )
                creadas += creada
                actualizadas += not creada

        self.stdout.write(self.style.SUCCESS(
            f"Listo: {creadas} pólizas creadas, {actualizadas} actualizadas."
        ))

    def _convertir(self, fila):
        estado = fila["estado"].strip()
        if estado == "vencida":
            raise ValueError(
                "el estado 'vencida' ya no existe: una póliza se renueva cada año y "
                "solo deja de valer si está 'cancelada' o 'suspendida'"
            )
        if estado not in RegistroAseguradora.Estado.values:
            raise ValueError(f"estado inválido: {estado!r}")

        datos = {
            "numero_poliza": fila["numero_poliza"].strip(),
            "aseguradora": fila["aseguradora"].strip(),
            "nombre": fila["nombre"].strip(),
            "apellido": fila["apellido"].strip(),
            "fecha_nacimiento": date.fromisoformat(fila["fecha_nacimiento"].strip()),
            "plan": fila["plan"].strip(),
            "prima_anual_gtq": Decimal(fila["prima_anual_gtq"].strip()),
            "deducible_gtq": Decimal(fila["deducible_gtq"].strip()),
            "coaseguro_pct": int(fila["coaseguro_pct"].strip()),
            "red": fila["red"].strip(),
            "vigencia_inicio": date.fromisoformat(fila["vigencia_inicio"].strip()),
            "vigencia_fin": date.fromisoformat(fila["vigencia_fin"].strip()),
            "estado": estado,
        }
        if not datos["numero_poliza"]:
            raise ValueError("numero_poliza vacío")
        if not 0 <= datos["coaseguro_pct"] <= 100:
            raise ValueError("coaseguro_pct debe estar entre 0 y 100")
        if datos["vigencia_fin"] < datos["vigencia_inicio"]:
            raise ValueError("vigencia_fin es anterior a vigencia_inicio")
        return datos
