from django.db import models
from Apps.core.models import ModeloBase, SoloAgregar, UserIdBase


class Ledger(SoloAgregar, UserIdBase):
    class TipoLedger(models.TextChoices):
        PASOS = "pasos", "Pasos"
        INTENSIDAD = "intensidad", "Intensidad"
        CHEQUEO_MEDICO = "chequeo_medico", "Chequeo médico"
        AJUSTE_MANUAL = "ajuste_manual", "Ajuste manual"
        RETROACTIVO_DENEGADO = "retroactivo_denegado", "Retroactivo denegado"

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
                # Los ajustes son correcciones por datos tardíos: un mismo
                # día puede necesitar varias, así que no se limitan a una.
                condition=~models.Q(tipo="ajuste_manual"),
            ),
        ]

    def __str__(self):
        return f"{self.usuario} - {self.puntos} pts - {self.tipo}"


class VersionRegla(ModeloBase):
    version = models.PositiveIntegerField(
        unique=True
    )
    vigente_desde = models.DateField()

    def __str__(self):
        return f"{self.version} -vigente desde - {self.vigente_desde}"