from django.db import models
from Apps.users.models import Usuario

# Create your models here.
class PolizaVinculada(models.Model):
    id = models.AutoField(primary_key=True)

    usuario = models.OneToOneField(
        Usuario,
        on_delete=models.PROTECT,
        db_column='usuario_id',
    )

    policy_number = models.CharField(max_length=100)
    insurer = models.CharField(max_length=100)
    policy_start_date = models.DateField()
    birth_date_confirmado = models.DateField(
        null=True
        blank=True
    )
    estado_verificación = models.CharField(
        max_length=10,
        choices=[
            ('pendiente', 'pendiente'),
            ('verificada', 'verificada'),
            ('rechazada', 'rechazada'),
        ]
    )

    fecha_vinculación = models.DateField(auto_now_add=True)
    fecha_verificación = models.DateField(
        null= True,
        blank=True
    )




