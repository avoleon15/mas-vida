from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator

# Create your models here.
class Season(models.Model):
    id = models.AutoField(primary_key=True)
    numero = models.CharField(
        validators=[
            MinValueValidator(1),
            MaxValueValidator(4)
        ]
    )
    anio = models.CharField()
    fecha_inicio = models.DateField()
    fecha_fin = models.DateField()


class ProgresoObjetivoUsuario(models.Model):
    id = models.AutoField(primary_key=True)
    

class MetaPasosObjetivos(models.Model):
    id = models.AutoField(primary_key=True)
    