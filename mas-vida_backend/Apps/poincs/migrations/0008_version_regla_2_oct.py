"""Crea la versión 2 de las reglas: las decisiones de la reunión del 2 oct 2026.

Cada fila de los ledgers (puntos y monedas) se sella con la versión de reglas
vigente en su fecha. La versión 2 empieza el 2 de octubre de 2026 y marca lo que
cambió en esa reunión: monedas sin tope que caducan al cerrar la season (antes
tope de 100 y 90 días), y lo que vaya entrando de ese paquete (pago por
componente, meta de pasos por edad, año de póliza). Lo anterior queda como
versión 1, para poder distinguir con qué reglas se ganó cada cosa.

Las filas que ya existen no se tocan (el ledger es append-only).
"""
from datetime import date

from django.db import migrations

VERSION = 2
VIGENTE_DESDE = date(2026, 10, 2)


def crear_version(apps, schema_editor):
    VersionRegla = apps.get_model("poincs", "VersionRegla")
    VersionRegla.objects.get_or_create(
        version=VERSION,
        defaults={"vigente_desde": VIGENTE_DESDE},
    )


class Migration(migrations.Migration):

    dependencies = [
        ("poincs", "0007_version_regla_inicial"),
    ]

    operations = [
        # Al revertir no se borra: el ledger la referencia con PROTECT.
        migrations.RunPython(crear_version, migrations.RunPython.noop),
    ]
