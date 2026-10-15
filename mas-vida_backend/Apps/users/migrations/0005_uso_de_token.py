"""El token vence a los 30 días sin uso (4 oct 2026).

Crea el registro del último uso y, para los tokens que ya existen, lo arranca en el
momento de migrar: todos los tokens de hoy tienen 30 días de margen desde el
despliegue. Sin esto, un token creado hace 40 días por alguien que usa la app a
diario se vencería de golpe al desplegar.
"""
import django.db.models.deletion
import django.utils.timezone
from django.db import migrations, models


def crear_usos_de_los_tokens_existentes(apps, schema_editor):
    Token = apps.get_model("authtoken", "Token")
    UsoDeToken = apps.get_model("users", "UsoDeToken")
    ahora = django.utils.timezone.now()
    UsoDeToken.objects.bulk_create(
        [UsoDeToken(token=token, ultimo_uso=ahora) for token in Token.objects.all()],
        ignore_conflicts=True,
    )


class Migration(migrations.Migration):

    dependencies = [
        ('authtoken', '0004_alter_tokenproxy_options'),
        ('users', '0004_intento_fallido'),
    ]

    operations = [
        migrations.CreateModel(
            name='UsoDeToken',
            fields=[
                ('id', models.AutoField(primary_key=True, serialize=False)),
                ('ultimo_uso', models.DateTimeField(default=django.utils.timezone.now)),
                ('token', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='uso', to='authtoken.token')),
            ],
            options={
                'abstract': False,
            },
        ),
        migrations.RunPython(crear_usos_de_los_tokens_existentes, migrations.RunPython.noop),
    ]
