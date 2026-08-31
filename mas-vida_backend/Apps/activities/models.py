from django.db import models

class Muestra(models.Model):
    usuario = models.ForeignKey(
        "users.Usuario",
        on_delete=models.CASCADE
    )

    external_id = models.CharField(
        max_length=255
    )

    inicio = models.DateTimeField()
    fin = models.DateTimeField()

    cantidad = models.PositiveIntegerField()

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

    class Meta:
            constraints = [
                models.UniqueConstraint(
                    fields=["usuario","external_id" ],
                    name="unique_muestra_usuario_external_id"
                )
            ]

    def __str__(self):
            return f"{self.usuario} - {self.cantidad} pasos"



class MuestraBPM(models.Model):
    usuario = models.ForeignKey(
            "users.Usuario",
            on_delete=models.CASCADE
    )

    external_id = models.CharField(
            max_length=255
        )

    inicio = models.DateTimeField()
    fin = models.DateTimeField()

    bpm = models.IntegerField()

    fuente_bundle = models.CharField(
          max_length=255
    )

    fuente_nombre = models.CharField(
    max_length=255
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["usuario","external_id" ],
                name="unique_muestra_bpm_external_id"
            )
        ]
    
    def __str__(self):
        return f"{self.usuario} - {self.bpm} BPM"


class Sesion(models.Model):
    usuario = models.ForeignKey(
            "users.Usuario",
            on_delete=models.CASCADE
              )
    
    external_id = models.CharField(
           max_length=255
           )
    inicio = models.DateTimeField()

    fin = models.DateTimeField()

    duracion_min = models.PositiveIntegerField()
    tipo_actividad = models.CharField(
          max_length=255
    )

    fc_promedio = models.PositiveIntegerField()

    fc_maxima = models.PositiveIntegerField()
    
    fuente_bundle = models.CharField(
          max_length=255
    )
    fuente_nombre = models.CharField(
          max_length=255
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