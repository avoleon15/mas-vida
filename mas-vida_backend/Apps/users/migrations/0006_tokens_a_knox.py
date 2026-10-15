"""Los tokens pasan a django-rest-knox (4 oct 2026; ver services/sesiones.py).

Cada token de DRF que sigue vigente se copia a Knox con la misma clave, así que
nadie tiene que volver a iniciar sesión: la app y Swift siguen mandando lo mismo.
Knox guarda solo el hash, y después se borran los de DRF, que estaban en claro.

- Vence en la misma fecha que tenía (último uso + 30 días). Los que ya habían
  vencido no se copian.
- El tope de 90 días cuenta desde que se migra.
- `UsoDeToken` desaparece: el vencimiento ahora lo lleva Knox.

Al revertir no se recuperan los tokens de DRF (solo queda el hash): hay que
volver a iniciar sesión.

Probada en PostgreSQL 16 (5 oct 2026) desplegando sobre una base de `dev` con
tokens: con uso, sin uso y vencido. Django desaconseja mezclar datos y esquema en
una migración en PostgreSQL ("pending trigger events"); con esta no pasó, ni hacia
adelante ni al revertir.
"""
import hashlib

import django.utils.timezone
from django.conf import settings
from django.db import migrations

# Las de Knox (knox.settings.CONSTANTS y knox.crypto.hash_token con SHA-512),
# copiadas para que la migración no cambie si Knox cambia.
LARGO_DE_TOKEN_KEY = 15


def _hash(clave: str) -> str:
    return hashlib.sha512(clave.encode("utf-8")).hexdigest()


def copiar_tokens_a_knox(apps, schema_editor):
    Token = apps.get_model("authtoken", "Token")
    UsoDeToken = apps.get_model("users", "UsoDeToken")
    AuthToken = apps.get_model("knox", "AuthToken")
    ahora = django.utils.timezone.now()
    vida = min(settings.REST_KNOX["TOKEN_TTL"], settings.REST_KNOX["AUTO_REFRESH_MAX_TTL"])
    usos = dict(UsoDeToken.objects.values_list("token_id", "ultimo_uso"))

    nuevos = []
    for token in Token.objects.all():
        vence = usos.get(token.key, token.created) + vida
        if vence <= ahora:
            continue
        nuevos.append(AuthToken(
            digest=_hash(token.key),
            token_key=token.key[:LARGO_DE_TOKEN_KEY],
            user_id=token.user_id,
            expiry=vence,
        ))
    AuthToken.objects.bulk_create(nuevos, ignore_conflicts=True)
    Token.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ("authtoken", "0004_alter_tokenproxy_options"),
        ("knox", "0009_extend_authtoken_field"),
        ("users", "0005_uso_de_token"),
    ]

    operations = [
        migrations.RunPython(copiar_tokens_a_knox, migrations.RunPython.noop),
        migrations.DeleteModel(name="UsoDeToken"),
    ]
