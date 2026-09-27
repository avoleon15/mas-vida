from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from Apps.core.models import ModeloBase, UserIdBase

# Create your models here.
class ObjetivoSemanal(ModeloBase):
    fecha_inicio = models.DateField(unique=True)
    fecha_fin = models.DateField()
    meta_pasos = models.PositiveIntegerField()
    meta_workouts = models.PositiveBigIntegerField()


class CumplimientoSemanal(UserIdBase):
    objetivo_semanal = models.ForeignKey(
        "ObjetivoSemanal",
        on_delete=models.PROTECT
        )
    pasos_semanales = models.PositiveIntegerField()
    workouts_acumulados = models.PositiveIntegerField()
    cumplido = models.BooleanField()
    evaluado_en = models.DateField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["usuario", "objetivo_semanal"],
                name="uq_cumplimiento_usuario_objetivo",
            ),
        ]


class Season(ModeloBase):
    numero = models.PositiveIntegerField(
        validators=[
        MinValueValidator(1),
        MaxValueValidator(4),
        ]
    )
    anio = models.PositiveIntegerField()
    fecha_inicio = models.DateField()
    fecha_fin = models.DateField()


class ProgresoObjetivoUsuario(UserIdBase):
    sesion = models.ForeignKey(
        "Season",
        on_delete=models.PROTECT 
    )
    objetivo_actual = models.PositiveIntegerField(default=1)
    objetivo_maximo_alcanzado = models.PositiveIntegerField()

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["usuario", "sesion"],
                name="uq_progreso_objetivo_usuario"
            )
        ]


class MetaPorPasosObjetivo(models.Model):
    objetivo_numero = models.PositiveIntegerField(
        primary_key=True,
        validators=[
            MinValueValidator(1),
            MaxValueValidator(13)
        ]
        )
    meta_pasos = models.PositiveIntegerField()



