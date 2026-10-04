"""Objetivo semanal por componente y meta de pasos por edad (2 oct 2026).

- ObjetivoSemanal: monedas de cada componente (5 + 5 provisional).
- MetaPasosPorEdad: tabla provisional de metas semanales de pasos por edad.
- CumplimientoSemanal: si se cumplió cada componente y la meta de pasos usada.
  Las filas que ya existían y estaban cumplidas quedan con los dos componentes
  cumplidos (antes había que cumplir los dos para cobrar).
"""
from django.db import migrations, models

# Tabla provisional del contrato ("Meta de pasos por edad", 2 oct 2026).
METAS = [(18, 49000), (30, 49000), (40, 45000), (50, 42000), (60, 35000), (70, 31000)]


def cargar_metas_y_marcar_cumplidos(apps, schema_editor):
    Meta = apps.get_model("objetivos", "MetaPasosPorEdad")
    for edad, pasos in METAS:
        Meta.objects.get_or_create(edad_desde=edad, defaults={"meta_pasos": pasos})

    Cumplimiento = apps.get_model("objetivos", "CumplimientoSemanal")
    for fila in Cumplimiento.objects.select_related("objetivo_semanal"):
        fila.meta_pasos = fila.objetivo_semanal.meta_pasos
        if fila.cumplido:
            fila.cumplio_pasos = fila.cumplio_workouts = True
        fila.save(update_fields=["meta_pasos", "cumplio_pasos", "cumplio_workouts"])


class Migration(migrations.Migration):

    dependencies = [
        ("objetivos", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="objetivosemanal",
            name="monedas_pasos",
            field=models.PositiveIntegerField(default=5),
        ),
        migrations.AddField(
            model_name="objetivosemanal",
            name="monedas_workouts",
            field=models.PositiveIntegerField(default=5),
        ),
        migrations.CreateModel(
            name="MetaPasosPorEdad",
            fields=[
                ("id", models.AutoField(primary_key=True, serialize=False)),
                ("edad_desde", models.PositiveSmallIntegerField(unique=True)),
                ("meta_pasos", models.PositiveIntegerField()),
            ],
            options={
                "ordering": ["edad_desde"],
                "verbose_name_plural": "metas de pasos por edad",
            },
        ),
        migrations.AddField(
            model_name="cumplimientosemanal",
            name="meta_pasos",
            field=models.PositiveIntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="cumplimientosemanal",
            name="cumplio_pasos",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="cumplimientosemanal",
            name="cumplio_workouts",
            field=models.BooleanField(default=False),
        ),
        migrations.RunPython(cargar_metas_y_marcar_cumplidos, migrations.RunPython.noop),
    ]
