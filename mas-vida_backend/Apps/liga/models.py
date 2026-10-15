from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from Apps.core.models import ModeloBase, UserIdBase


class LigaMensual(ModeloBase):
    mes = models.DateField(unique=True)
    total_participantes = models.PositiveIntegerField(
        null=True,
        blank=True
        )
    # El mes se CIERRA el día 2 (tabla final y quién ganó) y el podio se PAGA el día 9.
    cerrada_en = models.DateField(
        null=True,
        blank=True
    )
    # Cuándo se pagaron las monedas y los cupones del podio (None = todavía no).
    pagada_en = models.DateField(
        null=True,
        blank=True
    )


class PremioPodioLiga(ModeloBase):
    """Monedas que gana cada puesto del podio de La Liga (1.º, 2.º y 3.º).

    Decidido el 3 oct 2026: solo los 3 primeros ganan monedas. Los montos son
    provisionales hasta que los defina Diego, y se editan en el admin.
    """
    puesto = models.PositiveSmallIntegerField(
        unique=True,
        validators=(MinValueValidator(1), MaxValueValidator(3)),
    )
    monedas = models.PositiveIntegerField()

    class Meta:
        ordering = ["puesto"]

    def __str__(self):
        return f"Puesto {self.puesto}: {self.monedas} monedas"


class DesgloseLigaMensual(UserIdBase):
    liga_mensual = models.ForeignKey(
        LigaMensual,
        on_delete=models.PROTECT
    )
    pasos_acumulados_mes = models.PositiveIntegerField()
    # Segundo desempate: a igualdad de puntos y pasos gana quien tenga más workouts.
    workouts_acumulados_mes = models.PositiveIntegerField(default=0)
    posicion_final = models.PositiveIntegerField(null=True, blank=True)
    # La Liga compite por puntos (2 oct 2026); los pasos solo desempatan.
    puntos_mes = models.IntegerField(default=0)
    # Monedas que le tocan por el podio (0 fuera del podio). Se fijan al cerrar el mes y se
    # pagan el día 9, aunque los montos se editen en el admin entre una fecha y otra.
    monedas = models.PositiveIntegerField(default=0)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["usuario", "liga_mensual"],
                name='uq_usuario_liga_mensual'
            ),
        ]
        

class LigaAmigos(ModeloBase):
    creador_usuario = models.ForeignKey(
    "users.Usuario",
    on_delete=models.PROTECT,
    )
    nombre = models.CharField(max_length=255)
    mes = models.DateField()
    # Único en la base (etapa 7): el código se genera al azar y se revisa que no exista,
    # pero dos grupos creados a la vez podrían sacar el mismo. Ver services/ligas.py.
    codigo_invitacion = models.CharField(max_length=255, unique=True)

class MiembroLigaAmigos(UserIdBase):
    liga_amigos = models.ForeignKey(
        LigaAmigos,
        on_delete=models.PROTECT
    )
    pasos_acumulados_mes = models.PositiveIntegerField()
    fecha_union = models.DateField()

    class Meta:
        constraints = [
        models.UniqueConstraint(
            fields=["usuario", "liga_amigos"],
            name='uq_usuario_liga_amigos'
        )]
    





    
    