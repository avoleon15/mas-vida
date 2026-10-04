from django.conf import settings
from django.db import models
from Apps.core.models import ModeloBase


class Usuario(ModeloBase):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        db_column="user_id",
    )
    usuario_id = models.CharField(
        max_length=100,
        unique=True,
    )
    birth_date = models.DateField()
    
    def __str__(self):
        return self.usuario_id


class IdentidadExterna(ModeloBase):
    """La cuenta de Google o de Apple con la que una persona entra a +Vida.

    La identidad es (proveedor, sub): el `sub` es estable y único por persona en
    cada proveedor. No se guarda el correo (la cuenta de +Vida no tiene) y no se
    liga por correo a ninguna otra cuenta.
    """

    class Proveedor(models.TextChoices):
        GOOGLE = "google", "Google"
        APPLE = "apple", "Apple"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="identidades_externas",
    )
    proveedor = models.CharField(max_length=10, choices=Proveedor.choices)
    sub = models.CharField(max_length=255)
    creado_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["proveedor", "sub"], name="uq_identidad_proveedor_sub",
            ),
            # Una cuenta de +Vida tiene a lo sumo una de Google y una de Apple.
            models.UniqueConstraint(
                fields=["user", "proveedor"], name="uq_identidad_user_proveedor",
            ),
        ]

    def __str__(self):
        return f"{self.proveedor}:{self.user_id}"

