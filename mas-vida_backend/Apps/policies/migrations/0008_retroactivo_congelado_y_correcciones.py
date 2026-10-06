"""El veredicto del retroactivo se congela al verificar y las correcciones de fecha quedan registradas (5 oct 2026).

Antes, el corte se recalculaba cada vez comparando la fecha del registro con la
confirmada: si la aseguradora corregía su fecha DESPUÉS de verificar, el veredicto
podía cambiar solo y quitarle puntos a la persona por un error ajeno. Ahora se
guarda una vez (`retroactivo` y `corte_retroactivo`) y una corrección posterior
solo cambia la fecha hacia adelante (`CorreccionDeNacimiento`).

A las pólizas que ya estaban verificadas se les fija el veredicto que ya se les
había aplicado: hasta hoy, cualquier diferencia de fecha anulaba lo anterior.
"""
import django.db.models.deletion
from django.db import migrations, models
from django.utils import timezone


def fijar_el_veredicto_de_las_verificadas(apps, schema_editor):
    Poliza = apps.get_model("policies", "PolizaVinculada")
    for poliza in Poliza.objects.filter(estado_verificacion="verificada").select_related("usuario"):
        if poliza.birth_date_confirmada is None or poliza.fecha_verificacion is None:
            continue
        if poliza.birth_date_confirmada == poliza.usuario.birth_date:
            poliza.retroactivo = "aplicado"
        else:
            poliza.retroactivo = "denegado"
            poliza.corte_retroactivo = timezone.localtime(poliza.fecha_verificacion).date()
        poliza.save(update_fields=["retroactivo", "corte_retroactivo"])


class Migration(migrations.Migration):

    dependencies = [
        ('policies', '0007_poliza_verificada_unica'),
    ]

    operations = [
        migrations.AddField(
            model_name='polizavinculada',
            name='corte_retroactivo',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='polizavinculada',
            name='retroactivo',
            field=models.CharField(blank=True, choices=[('aplicado', 'Aplicado (la fecha coincide)'), ('tolerado', 'Tolerado (error sin ventaja)'), ('denegado', 'Denegado (mentira)')], default='', max_length=10),
        ),
        migrations.CreateModel(
            name='CorreccionDeNacimiento',
            fields=[
                ('id', models.AutoField(primary_key=True, serialize=False)),
                ('fecha_anterior', models.DateField()),
                ('fecha_nueva', models.DateField()),
                ('desde', models.DateField()),
                ('creada_en', models.DateTimeField(auto_now_add=True)),
                ('poliza', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='correcciones', to='policies.polizavinculada')),
            ],
            options={
                'ordering': ['desde', 'id'],
            },
        ),
        migrations.RunPython(fijar_el_veredicto_de_las_verificadas, migrations.RunPython.noop),
    ]
