from django.db import models

class Ledger(models.Model):
    usuario = models.ForeignKey(
        "users.Usuario",
        on_delete=models.CASCADE
    )

    puntos = models.IntegerField()
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