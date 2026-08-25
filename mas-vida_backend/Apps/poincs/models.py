from django.db import models

class Ledger(models.Model):
    usuario = models.ForeignKey(
        "users.Usuario",
        on_delete=models.CASCADE
    )

    puntos = models.IntegerField()
    tipo = models.CharField()
    fecha = models.DateField

    version_regla = models.ForeignKey(
        "points.VersionRegla",
        on_delete=models.CASCADE
    )
