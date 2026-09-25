from django.conf import settings
from django.db import models


class Usuario(models.Model):
    id = models.AutoField(primary_key=True)

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

