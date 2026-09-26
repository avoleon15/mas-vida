from django.db import models
from django.db import models


class Ledger(models.Model):
    class TipoLedger(models.TextChoices):
        PASOS = "pasos", "Pasos"
        INTENSIDAD = "intensidad", "Intensidad"
        CHEQUEO_MEDICO = "chequeo_medico", "Chequeo médico"
        AJUSTE_MANUAL = "ajuste_manual", "Ajuste manual"

    id = models.AutoField(primary_key=True)

    usuario = models.ForeignKey(
        "users.Usuario",
        on_delete=models.PROTECT,
    )

    puntos = models.IntegerField()

    tipo = models.CharField(
        max_length=50,
        choices=TipoLedger.choices,
    )

    fecha = models.DateField()

    creado_en = models.DateTimeField(auto_now_add=True)

    version_regla = models.ForeignKey(
        "VersionRegla",
        on_delete=models.PROTECT,
    )

    puntos_pasos = models.PositiveIntegerField(
        null=True,
        blank=True,
    )

    puntos_intensidad = models.PositiveIntegerField(
        null=True,
        blank=True,
    )

    tope_diario_aplicado = models.BooleanField(
        null=True,
        blank=True,
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["usuario", "fecha", "tipo", "version_regla"],
                name="uq_ledger_usuario_fecha_tipo_version",
            ),
        ]

    def __str__(self):
        return f"{self.usuario} - {self.puntos} pts - {self.tipo}"


class VersionRegla(models.Model):
    version = models.PositiveIntegerField(
        unique=True
    )
    vigente_desde = models.DateField()

    def __str__(self):
        return f"{self.version} -vigente desde - {self.vigente_desde}"