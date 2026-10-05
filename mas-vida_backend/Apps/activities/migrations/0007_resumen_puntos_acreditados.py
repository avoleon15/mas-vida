"""El resumen diario guarda los puntos ACREDITADOS (5 oct 2026).

Hasta ahora guardaba lo que calculó el día, antes del techo anual: pasado el techo
un día podía decir 200 y haber acreditado 0, y Progreso mostraba más puntos que
Mi Plan. El resumen es una tabla derivada (se puede reconstruir), así que aquí se
realinean las filas que ya existen con lo que dice el ledger. No se toca el ledger.
"""
from django.db import migrations
from django.db.models import Sum

# Las filas del ledger que componen los puntos de actividad de un día (no el chequeo médico).
TIPOS_DE_ACTIVIDAD = ["pasos", "intensidad", "ajuste_manual", "retroactivo_denegado"]


def alinear_con_el_ledger(apps, schema_editor):
    ResumenDiario = apps.get_model("activities", "ResumenDiario")
    Ledger = apps.get_model("poincs", "Ledger")
    acreditado = {
        (fila["usuario"], fila["fecha"]): fila["total"]
        for fila in (
            Ledger.objects.filter(tipo__in=TIPOS_DE_ACTIVIDAD)
            .values("usuario", "fecha").annotate(total=Sum("puntos"))
        )
    }
    for fila in ResumenDiario.objects.iterator():
        correcto = acreditado.get((fila.usuario_id, fila.fecha), 0)
        if fila.puntos_dia != correcto:
            fila.puntos_dia = correcto
            fila.save(update_fields=["puntos_dia"])


class Migration(migrations.Migration):

    dependencies = [
        ("activities", "0006_resumen_zonas_ritmo_cardiaco"),
        ("poincs", "0008_version_regla_2_oct"),
    ]

    operations = [
        # Al revertir no se deshace: el valor viejo no era más correcto.
        migrations.RunPython(alinear_con_el_ledger, migrations.RunPython.noop),
    ]
