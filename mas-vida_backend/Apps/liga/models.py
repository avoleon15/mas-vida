from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from Apps.core.models import ModeloBase, UserIdBase


class LigaMensual(ModeloBase):
    mes = models.DateField(unique=True)
    total_participantes = models.PositiveIntegerField(
        null=True,
        blank=True
        )
    cerrada_en = models.DateField(
        null=True,
        blank=True
    )
class TramoPremio(ModeloBase):
    orden = models.PositiveIntegerField(unique=True)
    percentil_hasta = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        validators = (MinValueValidator(1), MaxValueValidator(100)),
    )
    premio_descripcion = models.CharField()
    monedas = models.PositiveIntegerField(
        null=True,
        blank=True

    )

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(
                    percentil_hasta__gte=0,
                    percentil_hasta__lte=100,
                ),
                name="ck_tramo_percentil_hasta_0_100",
            ),
        ]
    
class DesgloseLigaMensual(UserIdBase):
    liga_mensual = models.ForeignKey(
        LigaMensual,
        on_delete=models.PROTECT
    )
    pasos_acumulados_mes = models.PositiveIntegerField()
    posicion_final = models.PositiveIntegerField(null=True, blank=True)
    percentil = models.DecimalField(
        null=True, 
        blank=True,
        max_digits=5,
        decimal_places=2,
        validators=(MinValueValidator(1), MaxValueValidator(100)),
        )
    tramo_premio = models.ForeignKey(
        TramoPremio,
        null=True, blank=True,
        on_delete=models.PROTECT
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["usuario", "liga_mensual"],
                name='uq_usuario_liga_mensual'
            ),
        models.CheckConstraint(
            condition=(
                models.Q(percentil__isnull=True)
                | models.Q(percentil__gte=0, percentil__lte=100)
            ),
            name="ck_desglose_percentil_0_100",
        ),
    ]
        

class LigaAmigos(ModeloBase):
    creador_usuario = models.ForeignKey(
    "users.Usuario",
    on_delete=models.PROTECT,
    )
    nombre = models.CharField()
    mes = models.DateField()
    codigo_invitacion = models.CharField()

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
    





    
    