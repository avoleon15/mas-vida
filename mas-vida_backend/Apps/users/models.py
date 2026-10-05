from django.conf import settings
from django.db import models
from django.utils import timezone
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


class IntentoFallido(ModeloBase):
    """Un intento que no salió bien, para poder limitar los siguientes.

    Vive en la base de datos y no en memoria: el límite tiene que valer igual
    con varios procesos del servidor y sobrevivir a un reinicio. La `clave` es
    lo que se limita (la IP, la cuenta o un hash del número de póliza; nunca el
    número en claro). Ver services/intentos.py.
    """

    tipo = models.CharField(max_length=20)
    clave = models.CharField(max_length=64)
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        indexes = [models.Index(fields=["tipo", "clave", "creado_en"])]

    def __str__(self):
        return f"{self.tipo} {self.clave[:12]} {self.creado_en:%Y-%m-%d %H:%M}"
