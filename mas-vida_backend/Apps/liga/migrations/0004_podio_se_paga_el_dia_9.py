"""El podio de La Liga se cierra el día 2 y se paga el día 9 (6 oct 2026).

Hasta hoy el cierre pagaba en el acto. Un mes ya cerrado se marca como pagado el
mismo día en que se cerró, para que el pago del día 9 no lo pague otra vez.
"""
from django.db import migrations, models
from django.db.models import F


def marcar_pagados_los_meses_ya_cerrados(apps, schema_editor):
    LigaMensual = apps.get_model("liga", "LigaMensual")
    LigaMensual.objects.filter(cerrada_en__isnull=False, pagada_en__isnull=True).update(pagada_en=F("cerrada_en"))


class Migration(migrations.Migration):

    dependencies = [
        ('liga', '0003_podio_por_puntos'),
    ]

    operations = [
        migrations.AddField(
            model_name='ligamensual',
            name='pagada_en',
            field=models.DateField(blank=True, null=True),
        ),
        migrations.RunPython(marcar_pagados_los_meses_ya_cerrados, migrations.RunPython.noop),
    ]
