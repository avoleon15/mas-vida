"""Póliza anual (reunión del 2 oct 2026).

- Registro simulado: la prima pasa de mensual a ANUAL. Se renombra el campo y
  se multiplica por 12 lo que ya estaba cargado (no se pierde nada).
- Registro simulado: deja de existir el estado "vencida" (una póliza médica se
  renueva, no vence). Las filas que lo tuvieran pasan a "vigente".
- Póliza vinculada: guarda lo que entrega la aseguradora al verificar
  (nombre, apellido, plan, prima anual y fecha de renovación).
"""
from decimal import Decimal

from django.db import migrations, models


def a_prima_anual_y_sin_vencida(apps, schema_editor):
    Registro = apps.get_model("policies", "RegistroAseguradora")
    for registro in Registro.objects.all():
        registro.prima_anual_gtq = registro.prima_anual_gtq * Decimal(12)
        if registro.estado == "vencida":
            registro.estado = "vigente"
        registro.save(update_fields=["prima_anual_gtq", "estado"])


def a_prima_mensual(apps, schema_editor):
    Registro = apps.get_model("policies", "RegistroAseguradora")
    for registro in Registro.objects.all():
        registro.prima_anual_gtq = (registro.prima_anual_gtq / Decimal(12)).quantize(Decimal("0.01"))
        registro.save(update_fields=["prima_anual_gtq"])


class Migration(migrations.Migration):

    dependencies = [
        ("policies", "0005_registro_aseguradora_y_motivo_rechazo"),
    ]

    operations = [
        migrations.RenameField(
            model_name="registroaseguradora",
            old_name="prima_mensual_gtq",
            new_name="prima_anual_gtq",
        ),
        migrations.RunPython(a_prima_anual_y_sin_vencida, a_prima_mensual),
        migrations.AlterField(
            model_name="registroaseguradora",
            name="estado",
            field=models.CharField(
                choices=[("vigente", "Vigente"), ("cancelada", "Cancelada"), ("suspendida", "Suspendida")],
                max_length=10,
            ),
        ),
        migrations.AddField(
            model_name="polizavinculada",
            name="nombre",
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name="polizavinculada",
            name="apellido",
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name="polizavinculada",
            name="plan",
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name="polizavinculada",
            name="prima_anual_gtq",
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name="polizavinculada",
            name="fecha_renovacion",
            field=models.DateField(blank=True, null=True),
        ),
    ]
