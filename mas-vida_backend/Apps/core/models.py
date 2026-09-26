from django.db import models


class ModeloBase(models.Model):
    id = models.AutoField(primary_key=True)
    class Meta:
        abstract = True

class UserIdBase(ModeloBase):
    usuario = models.ForeignKey(
        "users.Usuario",
        on_delete=models.PROTECT      
    )
    class Meta:
        abstract = True

