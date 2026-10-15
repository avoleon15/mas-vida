"""Limpieza del modelo viejo de La Liga y código de invitación único (etapa 7, 14 oct 2026).

- Se borran TramoPremio y los campos percentil y tramo_premio de DesgloseLigaMensual: eran
  de los premios por percentil, reemplazados el 3 oct 2026 por el podio de los 3 primeros.
  Nunca se llenaron.
- El código de invitación de Tus Ligas pasa a ser único en la base. Si ya hay dos grupos
  con el mismo código, la migración se detiene y los lista: hay que cambiar uno a mano.
"""
from collections import defaultdict

from django.db import migrations, models


def verificar_que_no_haya_codigos_repetidos(apps, schema_editor):
    LigaAmigos = apps.get_model("liga", "LigaAmigos")
    grupos = defaultdict(list)
    for pk, codigo in LigaAmigos.objects.values_list("pk", "codigo_invitacion"):
        grupos[codigo].append(pk)
    repetidos = {codigo: pks for codigo, pks in grupos.items() if len(pks) > 1}
    if repetidos:
        raise RuntimeError(
            "Hay grupos de Tus Ligas con el mismo código de invitación. Cambia el código de "
            f"todos menos uno y vuelve a migrar: {repetidos}"
        )


class Migration(migrations.Migration):

    dependencies = [
        ('liga', '0004_podio_se_paga_el_dia_9'),
    ]

    operations = [
        migrations.RunPython(verificar_que_no_haya_codigos_repetidos, migrations.RunPython.noop),
        migrations.RemoveConstraint(
            model_name='tramopremio',
            name='ck_tramo_percentil_hasta_0_100',
        ),
        migrations.RemoveConstraint(
            model_name='desgloseligamensual',
            name='ck_desglose_percentil_0_100',
        ),
        migrations.AlterField(
            model_name='ligaamigos',
            name='codigo_invitacion',
            field=models.CharField(max_length=255, unique=True),
        ),
        migrations.RemoveField(
            model_name='desgloseligamensual',
            name='percentil',
        ),
        migrations.RemoveField(
            model_name='desgloseligamensual',
            name='tramo_premio',
        ),
        migrations.DeleteModel(
            name='TramoPremio',
        ),
    ]
