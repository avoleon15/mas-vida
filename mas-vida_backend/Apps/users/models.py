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

