"""Crea la versión 1 de las reglas de puntaje.

Sin ninguna VersionRegla, `POST /api/v1/sync` responde 500: cada fila del
ledger se sella con la versión vigente y no habría cuál usar. Como es una
migración, se aplica sola en cualquier despliegue que corra `migrate`.

vigente_desde = 1 de enero de 2026: cubre todo lo que el piloto puede
sincronizar (la ventana de datos rezagados es de 14 días).
"""
from datetime import date

from django.db import migrations

VERSION_INICIAL = 1
VIGENTE_DESDE = date(2026, 1, 1)


def crear_version_inicial(apps, schema_editor):
    VersionRegla = apps.get_model("poincs", "VersionRegla")
    # get_or_create: una base que ya la tenía (cargada a mano o con
    # sembrar_prueba) queda igual.
    VersionRegla.objects.get_or_create(
        version=VERSION_INICIAL,
        defaults={"vigente_desde": VIGENTE_DESDE},
    )


class Migration(migrations.Migration):

    dependencies = [
        ("poincs", "0006_alter_ledger_tipo"),
    ]

    operations = [
        # Al revertir no se borra: el ledger la referencia con PROTECT.
        migrations.RunPython(crear_version_inicial, migrations.RunPython.noop),
    ]
