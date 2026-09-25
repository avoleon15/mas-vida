from django.db import models
from django.db.models import Q
from django.core.validators import MaxValueValidator, MinValueValidator

class Muestra(models.Model):

    id = models.AutoField(primary_key=True)

    usuario = models.ForeignKey(
        "users.Usuario",
        on_delete=models.PROTECT
        
    )

    external_id = models.CharField(
        max_length=255
    )

    inicio = models.DateTimeField()
    fin = models.DateTimeField()
    cantidad = models.PositiveIntegerField(
          validators=[MaxValueValidator(3000)]
    )

    fuente_bundle = models.CharField(
        max_length=255
    )
        
    fuente_nombre = models.CharField(
        max_length=255
    )

    fuente_version = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )

    dispositivo_nombre = models.CharField(
          max_length=255,
          blank=True,
          null=True
    )
    dispositivo_modelo = models.CharField(
          max_length=255,
          blank=True,
          null=True
    )

    dispositivo_fabricante = models.CharField(
          max_length=255,
          null=True,
          blank=True
    )

    class Meta:
            constraints = [
                models.UniqueConstraint(
                    fields=["usuario","external_id" ],
                    name="unique_muestra_usuario_external_id"
                ),
                models.CheckConstraint(
                      condition=Q(cantidad__lte=3000),
                      name='ck_muestra_cantidad_max_3000'
                )
            ]


    def __str__(self):
            return f"{self.usuario} - {self.cantidad} pasos"



class MuestraBPM(models.Model):
    id = models.AutoField(primary_key=True)

    usuario = models.ForeignKey(
            "users.Usuario",
            on_delete=models.PROTECT
    )

    external_id = models.CharField(
            max_length=255
        )

    inicio = models.DateTimeField()
    fin = models.DateTimeField()

    bpm = models.PositiveSmallIntegerField(
          validators=[
                MinValueValidator(30),
                MaxValueValidator(230)
          ]
    )

    fuente_bundle = models.CharField(
           max_length=255
       )
           
    fuente_nombre = models.CharField(
        max_length=255
    )

    fuente_version = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )

    dispositivo_nombre = models.CharField(
            max_length=255,
            blank=True,
            null=True
    )
    dispositivo_modelo = models.CharField(
            max_length=255,
            blank=True,
            null=True
    )

    dispositivo_fabricante = models.CharField(
            max_length=255,
            null=True,
            blank=True
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["usuario","external_id" ],
                name="unique_muestra_bpm_external_id"
            ),

            models.CheckConstraint(
                  condition=Q(bpm__gte=30, bpm__lte=230),
                  name='ck_muestra_cantidad_max_3000'
            )
            
        ]
    
    def __str__(self):
        return f"{self.usuario} - {self.bpm} BPM"


class Sesion(models.Model):

    id = models.AutoField(primary_key=True)

    usuario = models.ForeignKey(
            "users.Usuario",
            on_delete=models.PROTECT
              )
    
    external_id = models.CharField(
           max_length=255
           )
    inicio = models.DateTimeField()

    fin = models.DateTimeField()

    duracion_min = models.PositiveIntegerField()
    tipo_actividad = models.CharField(
          max_length=255,
          null=True,
          blank=True,
    )

    fc_promedio = models.PositiveIntegerField()

    fc_maxima = models.PositiveIntegerField()
    
    fuente_bundle = models.CharField(
          max_length=255
    )
    fuente_nombre = models.CharField(
          max_length=255
    )
    
    fuente_version = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )

    dispositivo_nombre = models.CharField(
            max_length=255,
            blank=True,
            null=True
    )
    dispositivo_modelo = models.CharField(
            max_length=255,
            blank=True,
            null=True
    )

    dispositivo_fabricante = models.CharField(
            max_length=255,
            null=True,
            blank=True
    )

    class Meta:
            constraints = [
                models.UniqueConstraint(
                    fields=["usuario","external_id" ],
                    name="unique_sesion_usuario_external_id"
                )
            ]
    def __str__(self):
          return f"{self.usuario} - {self.tipo_actividad} - {self.duracion_min}"


    class ResumenDiario(models.Model):
        id =models.AutoField(primary_key=True)
        usuario = models.ForeignKey(
                    "users.Usuario",
                    on_delete=models.PROTECT
                    )
        fecha = models.DateField()
        pasos_totales_dia = models.IntegerField()
        workouts_cantidad = models.IntegerField(
            null=True,
            blank=True
        )
        workouts_duracion_total_min = models.IntegerField(
            null=True,
            blank=True
        )
        workouts_fc_promedio = models.IntegerField(
            null=True,
            blank=True
        )
        workouts_fc_maxima = models.IntegerField(
            null=True,
            blank=True
        )
        puntos_dia = models.IntegerField()

        class Meta:
             constraints = [
                  models.UniqueConstraint(
                       fields=['usuario', 'fecha'],
                       name='uq_resumen_diario_usuario_fecha',
                  ),
             ]

              

