from django.conf import settings
from django.db import models
from django.utils import timezone
from Apps.core.models import ModeloBase, UserIdBase


class Usuario(ModeloBase):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        db_column="user_id",
    )
    usuario_id = models.CharField(
        max_length=100,
        unique=True,
    )
    birth_date = models.DateField()
    # Cuándo pidió la baja de su cuenta (None = activa). Ver services/baja.py.
    dado_de_baja_en = models.DateTimeField(null=True, blank=True)
    
    def __str__(self):
        return self.usuario_id


class Consentimiento(UserIdBase):
    """Que la persona aceptó compartir con la aseguradora sus datos del día.

    Se guarda cuándo aceptó, qué versión del texto vio y si lo revocó. Aceptar otra vez
    (o una versión nueva del texto) agrega otra fila: el historial no se borra. Solo el
    texto vigente cuenta (ver services/consentimiento.py).
    """

    version = models.CharField(max_length=20)
    aceptado_en = models.DateTimeField(default=timezone.now)
    revocado_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            # Una sola aceptación sin revocar por versión: dos taps seguidos no la duplican.
            models.UniqueConstraint(
                fields=["usuario", "version"],
                condition=models.Q(revocado_en__isnull=True),
                name="uq_consentimiento_sin_revocar_por_version",
            ),
        ]

    def __str__(self):
        estado = "revocado" if self.revocado_en else "vigente"
        return f"{self.usuario_id} v{self.version} {estado}"


class IntentoFallido(ModeloBase):
    """Un intento que no salió bien, para poder limitar los siguientes.

    Vive en la base de datos y no en memoria: el límite tiene que valer igual
    con varios procesos del servidor y sobrevivir a un reinicio. La `clave` es
    lo que se limita (la IP, la cuenta o un hash del número de póliza; nunca el
    número en claro). Ver services/intentos.py.
    """

    tipo = models.CharField(max_length=20)
    clave = models.CharField(max_length=64)
    creado_en = models.DateTimeField(default=timezone.now)

    class Meta:
        indexes = [models.Index(fields=["tipo", "clave", "creado_en"])]

    def __str__(self):
        return f"{self.tipo} {self.clave[:12]} {self.creado_en:%Y-%m-%d %H:%M}"
