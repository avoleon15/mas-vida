from django.db import models
from Apps.core.models import ModeloBase

# Create your models here.
class PolizaVinculada(ModeloBase):
    usuario = models.OneToOneField(
        'users.Usuario',
        on_delete=models.PROTECT,
        db_column='usuario_id',
    )

    policy_number = models.CharField(max_length=100)
    insurer = models.CharField(max_length=100)
    policy_start_date = models.DateField()
    birth_date_confirmada = models.DateField(
        null=True,
        blank=True
    )
    estado_verificacion = models.CharField(
        max_length=10,
        choices=[
            ('pendiente', 'pendiente'),
            ('verificada', 'verificada'),
            ('rechazada', 'rechazada'),
        ]
    )

    fecha_vinculacion = models.DateTimeField(auto_now_add=True)
    fecha_verificacion = models.DateTimeField(
        null= True,
        blank=True
    )




