"""El correo de una cuenta: sin distinguir mayúsculas y sin repetirse (etapa 14, 6 oct 2026).

En las cuentas con contraseña la app guarda el correo como `username`; las de Google y
Apple lo guardan en `User.email`. `Ana@correo.com` y `ana@correo.com` son la misma
persona, así que dos cuentas nunca pueden diferir solo en las mayúsculas, ni una tomar
el correo que ya tiene otra, sea cual sea la forma en que entró.

El correo se guarda como lo escribió la persona (no se reescribe nada); lo que cambia es
cómo se compara. Un índice único en la base (`users/0007`) lo garantiza aunque dos
registros lleguen a la vez.
"""
from django.contrib.auth import get_user_model
from django.db.models import Q

User = get_user_model()


def limpiar(valor) -> str:
    return valor.strip() if isinstance(valor, str) else ""


def correo_en_uso(valor, excluir_pk=None) -> bool:
    """Si ya hay OTRA cuenta con ese correo, sea como `username` o como `email`.

    `excluir_pk` deja fuera a la propia cuenta (al editarla en el admin).
    """
    valor = limpiar(valor)
    if not valor:
        return False
    otras = User.objects.filter(Q(username__iexact=valor) | Q(email__iexact=valor))
    if excluir_pk is not None:
        otras = otras.exclude(pk=excluir_pk)
    return otras.exists()


def nombre_para_entrar(valor):
    """El `username` exacto de la cuenta que la persona quiso decir, sin importar mayúsculas.

    Si escribió `ANA@correo.com` y la cuenta quedó como `Ana@correo.com`, devuelve
    `Ana@correo.com` para que `authenticate` la encuentre. Si no hay cuenta (o no se puede
    decidir), devuelve lo que escribió y el login falla como siempre, sin revelar nada.
    """
    if not isinstance(valor, str):
        return valor
    escrito = valor.strip()
    if User.objects.filter(username=escrito).exists():
        return escrito
    parecidos = list(User.objects.filter(username__iexact=escrito).values_list("username", flat=True)[:2])
    return parecidos[0] if len(parecidos) == 1 else escrito
