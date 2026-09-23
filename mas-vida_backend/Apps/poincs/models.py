from django.db import models

class Ledger(models.Model):
    usuario = models.ForeignKey(
        "users.Usuario",
        on_delete=models.CASCADE
    )

    puntos = models.IntegerField()

    puntos_pasos = models.PositiveIntegerField(
        null=True,
        blank=True
    )

    puntos_intensidad = models.PositiveIntegerField(
        null=True,
        blank=True
    )

    tope_diario_aplicado = models.BooleanField(
        null=True,
        blank=True
    )


    tipo = models.CharField(
        max_length=50
    )
    fecha = models.DateField()

    version_regla = models.ForeignKey(
        "VersionRegla",
        on_delete=models.PROTECT
    )

    def __str__(self):
        return f"{self.usuario} - {self.puntos} pts - {self.tipo}"


class VersionRegla(models.Model):
    version = models.PositiveIntegerField(
        unique=True
    )
    vigente_desde = models.DateField()

    def __str__(self):
        return f"{self.version} -vigente desde - {self.vigente_desde}"