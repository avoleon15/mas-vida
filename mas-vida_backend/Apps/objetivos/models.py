from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from Apps.core.models import ModeloBase, UserIdBase

# Create your models here.
class ObjetivoSemanal(ModeloBase):
    fecha_inicio = models.DateField(unique=True)
    fecha_fin = models.DateField()
    # Respaldo: la meta de pasos sale de MetaPasosPorEdad (2 oct 2026). Solo
    # se usa si esa tabla está vacía.
    meta_pasos = models.PositiveIntegerField()
    meta_workouts = models.PositiveBigIntegerField()
    # Cada componente paga sus monedas por separado (2 oct 2026). Las manda el
    # servidor semana por semana; se editan en el admin.
    monedas_pasos = models.PositiveIntegerField(default=5)
    monedas_workouts = models.PositiveIntegerField(default=5)


class MetaPasosPorEdad(ModeloBase):
    """Meta semanal de pasos según el rango de edad, de 10 en 10 años (2 oct 2026).

    Cada fila vale desde `edad_desde` hasta el `edad_desde` de la siguiente
    menos uno; la última no tiene tope. Una edad menor a la primera usa la
    primera fila. Provisional: se ajusta con los datos del piloto.
    """

    edad_desde = models.PositiveSmallIntegerField(unique=True)
    meta_pasos = models.PositiveIntegerField()

    class Meta:
        ordering = ["edad_desde"]
        verbose_name_plural = "metas de pasos por edad"

    def __str__(self):
        return f"desde {self.edad_desde} años: {self.meta_pasos} pasos"


class CumplimientoSemanal(UserIdBase):
    objetivo_semanal = models.ForeignKey(
        "ObjetivoSemanal",
        on_delete=models.PROTECT
        )
    pasos_semanales = models.PositiveIntegerField()
    workouts_acumulados = models.PositiveIntegerField()
    # Semana COMPLETADA: los dos componentes cumplidos.
    cumplido = models.BooleanField()
    evaluado_en = models.DateField(null=True, blank=True)
    # Cada componente por separado, y la meta de pasos que se usó (depende de
    # la edad del usuario esa semana).
    meta_pasos = models.PositiveIntegerField(null=True, blank=True)
    cumplio_pasos = models.BooleanField(default=False)
    cumplio_workouts = models.BooleanField(default=False)

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



