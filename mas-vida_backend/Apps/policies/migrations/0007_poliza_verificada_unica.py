"""Una cuenta verificada por póliza (4 oct 2026).

Antes de crear la restricción se revisa que no haya ya dos cuentas verificadas con
la misma póliza. Si las hay, la migración se detiene y dice cuáles son: decidir
cuál conserva la póliza es cosa de una persona (no se apaga ninguna sola).
"""
import django.db.models.functions.text
from django.db import migrations, models


def revisar_duplicadas(apps, schema_editor):
    Poliza = apps.get_model("policies", "PolizaVinculada")
    vistas = {}
    repetidas = []
    for fila in Poliza.objects.filter(estado_verificacion="verificada").order_by("id"):
        clave = (fila.insurer.strip().lower(), fila.policy_number.strip().lower())
        if clave in vistas:
            repetidas.append((fila.policy_number, vistas[clave], fila.usuario_id))
        else:
            vistas[clave] = fila.usuario_id
    if repetidas:
        detalle = "; ".join(
            f"{numero} (usuarios {primero} y {segundo})" for numero, primero, segundo in repetidas
        )
        raise RuntimeError(
            "Hay pólizas verificadas en más de una cuenta: " + detalle + ". Deja una sola "
            "por póliza (cambia el estado de las demás a 'rechazada' directo en la base de datos, "
            "porque el admin no deja rechazar una verificada) y vuelve a migrar."
        )


class Migration(migrations.Migration):

    dependencies = [
        ('policies', '0006_poliza_anual'),
        ('users', '0004_intento_fallido'),
    ]

    operations = [
        migrations.RunPython(revisar_duplicadas, migrations.RunPython.noop),
        migrations.AddConstraint(
            model_name='polizavinculada',
            constraint=models.UniqueConstraint(django.db.models.functions.text.Lower(django.db.models.functions.text.Trim('insurer')), django.db.models.functions.text.Lower(django.db.models.functions.text.Trim('policy_number')), condition=models.Q(('estado_verificacion', 'verificada')), name='uq_poliza_verificada_en_una_cuenta'),
        ),
    ]
