"""Carga el catálogo de premios desde un JSON con la forma del mock de la app.

    python manage.py importar_premios ../DEMO/vida_demo/assets/mock/premios.json

Es idempotente: un premio se identifica por (nombre, comercio) y, si ya
existe, se actualiza. No borra ni apaga nada: lo que ya no esté en el archivo
se apaga a mano en el admin. Todo o nada: si un premio viene mal, no se guarda
ninguno.
"""
import json
from datetime import date

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from Apps.coins.models import Premio


class Command(BaseCommand):
    help = "Carga o actualiza el catálogo de premios desde un JSON."

    def add_arguments(self, parser):
        parser.add_argument("ruta", help="JSON con la clave 'premios' (forma del mock).")

    def handle(self, *args, ruta, **opciones):
        try:
            with open(ruta, encoding="utf-8") as archivo:
                datos = json.load(archivo)
        except (OSError, ValueError) as e:
            raise CommandError(f"No se pudo leer {ruta}: {e}")
        if not isinstance(datos.get("premios"), list):
            raise CommandError("El archivo no trae una lista 'premios'.")

        creados = actualizados = 0
        with transaction.atomic():
            for numero, p in enumerate(datos["premios"], start=1):
                try:
                    creado = self._guardar(p)
                except (AttributeError, KeyError, TypeError, ValueError) as e:
                    raise CommandError(f"El premio #{numero} viene mal ({e!r}). No se guardó nada.")
                creados += creado
                actualizados += not creado
        self.stdout.write(f"Premios: {creados} creados, {actualizados} actualizados.")

    def _guardar(self, p) -> bool:
        if not isinstance(p.get("costo_monedas"), int) or p["costo_monedas"] < 0:
            raise ValueError("costo_monedas tiene que ser un entero de 0 o más")
        _, creado = Premio.objects.update_or_create(
            nombre=p["nombre"],
            comercio_aliado=p["nombre"],
            defaults={
                "descripcion": p["descripcion"],
                "costo_monedas": p["costo_monedas"],
                "zona": p.get("zona") or "Guatemala",
                "categoria": p.get("categoria") or "",
                "detalle": p.get("detalle") or "",
                "condiciones": p.get("condiciones") or "",
                "foto": p.get("foto") or "",
                "fondo": p.get("fondo") or "",
                "vigente_hasta": date.fromisoformat(p["vence"]) if p.get("vence") else None,
            },
        )
        return creado
