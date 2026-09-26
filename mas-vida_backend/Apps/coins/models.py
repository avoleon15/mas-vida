from django.db import models
from Apps.core.models import UserIdBase, ModeloBase

# Create your models here.
class MonedaLedger(UserIdBase):
    class Tipo(models.TextChoices):
        OBJETIVO_CUMPLIDO = 'objetivo_cumplido', 'Objetivo cumplido'
        LIGA_MENSUAL = 'liga_mensual', 'Liga mensual'
        CANJE = 'canje', 'Canje'
        EXPIRACION = 'expiracion', 'Expiracion'
        AJUSTE_MANUAL = 'ajuste_manual', 'Ajuste manual'
    
    cantidad = models.IntegerField()
    tipo = models.CharField(
        max_length=50,
        choices=Tipo.choices,
    )
    fecha = models.DateField()
    fecha_expiracion = models.DateField(null=True, blank=True)
    creado_en = models.DateTimeField(auto_now_add=True)
    version_regla = models.ForeignKey(
        "poincs.VersionRegla",
        on_delete=models.PROTECT
    )

class Premio(ModeloBase):
    nombre = models.CharField(max_length=150)
    descripcion = models.TextField()
    costo_monedas = models.PositiveIntegerField()
    comercio_aliado = models.CharField(max_length=150)

class Canje(UserIdBase):
    class Estado(models.TextChoices):
        ACTIVO = 'activo', 'Activo'
        USADO = 'usado', 'Usado'
        EXPIRADO = 'expirado', 'Expirado'

    premio = models.ForeignKey(
        Premio,
        on_delete=models.PROTECT
    )
    costo_monedas = models.PositiveIntegerField()
    fecha_canje  = models.DateTimeField()
    fecha_expiracion_cupon = models.DateField()
    estado = models.CharField(
        max_length=50,
        choices=Estado.choices
    )

