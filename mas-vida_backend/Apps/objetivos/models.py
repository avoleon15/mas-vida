from django.db import models
from django.core.validators import MaxLengthValidator, MinLengthValidator

# Create your models here.
class ObjetivoSemanal(models.Model):

    id = models.AutoField(primary_key=True)
    fecha_inicio = models.DateField(unique=True)
    fecha_fin = models.DateField()
    meta_pasos = models.PositiveIntegerField()
    meta_workouts = models.PositiveBigIntegerField()


class CumplimientoSemanal(models.Model):
    id = models.AutoField(primary_key=True)
    usuario = models.ForeignKey(
        'users.Usuario',
        on_delete=models.PROTECT,
    )

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


class Season(models.Model):
    id = models.AutoField(primary_key=True)
    numero = models.PositiveIntegerField(
        validators=[
        MinLengthValidator(1),
        MaxLengthValidator(4),
        ]
    )
    anio = models.PositiveIntegerField()
    fecha_inicio = models.DateField()
    fecha_fin = models.DateField()


class ProgresoObjetivoUsuario(models.Model):
    id = models.AutoField(primary_key=True)
    usuario =  models.ForeignKey(
        "users.Usuario",
        on_delete=models.PROTECT
    )
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
            MinLengthValidator(1),
            MaxLengthValidator(13)
        ]
        )
    meta_pasos = models.PositiveIntegerField()



