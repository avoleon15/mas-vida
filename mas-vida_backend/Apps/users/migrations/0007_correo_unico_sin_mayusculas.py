"""Dos cuentas no pueden tener el mismo correo aunque difieran en las mayúsculas (6 oct 2026).

`Ana@correo.com` y `ana@correo.com` eran dos cuentas distintas. Los índices únicos
sobre `LOWER(username)` y `LOWER(email)` lo impiden en la base, también si dos registros
llegan a la vez. El correo de las cuentas de Google y Apple va en `email` (puede estar
vacío: solo se exige único cuando hay uno).

Si la base ya tiene dos cuentas que solo difieren en las mayúsculas, la migración se
detiene y las lista: hay que resolverlas a mano (cuál se queda) antes de seguir.
"""
from collections import defaultdict

from django.db import migrations


def verificar_que_no_haya_repetidos(apps, schema_editor):
    User = apps.get_model("auth", "User")
    grupos = defaultdict(list)
    for pk, username, email in User.objects.values_list("pk", "username", "email"):
        grupos[("username", username.casefold())].append((pk, username))
        if email:
            grupos[("email", email.casefold())].append((pk, email))
    repetidos = {clave: filas for clave, filas in grupos.items() if len(filas) > 1}
    if repetidos:
        detalle = "; ".join(f"{campo} {valor!r}: {filas}" for (campo, valor), filas in repetidos.items())
        raise RuntimeError(
            "Hay cuentas con el mismo correo que solo difieren en las mayúsculas. "
            f"Resuélvelas a mano (deja una y cambia o borra las demás) y vuelve a migrar: {detalle}"
        )


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0006_tokens_a_knox"),
        ("auth", "0012_alter_user_first_name_max_length"),
    ]

    operations = [
        migrations.RunPython(verificar_que_no_haya_repetidos, migrations.RunPython.noop),
        migrations.RunSQL(
            sql="CREATE UNIQUE INDEX uq_auth_user_username_lower ON auth_user (LOWER(username))",
            reverse_sql="DROP INDEX uq_auth_user_username_lower",
        ),
        migrations.RunSQL(
            sql="CREATE UNIQUE INDEX uq_auth_user_email_lower ON auth_user (LOWER(email)) WHERE email <> ''",
            reverse_sql="DROP INDEX uq_auth_user_email_lower",
        ),
    ]
