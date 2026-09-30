from django.db import models
from Apps.core.models import ModeloBase


class PolizaVinculada(ModeloBase):
    """Póliza que un usuario vincula después de registrarse.

    Una cuenta base (gratis) no tiene póliza; esta fila solo existe cuando el
    usuario ya ingresó una. Todo lo que implica dinero real (cashback, canje
    de monedas, La Liga) exige que la póliza esté verificada, no solo
    vinculada.
    """

    class EstadoVerificacion(models.TextChoices):
        # "pendiente" se trata igual que "sin póliza" en cualquier gate de
        # recompensa: no hay un tercer estado visible para el usuario.
        PENDIENTE = 'pendiente', 'Pendiente'
        VERIFICADA = 'verificada', 'Verificada'
        RECHAZADA = 'rechazada', 'Rechazada'

    # PROTECT: borrar el Usuario no debe llevarse la póliza por delante.
    # related_name hace que se acceda como usuario.poliza.
    usuario = models.OneToOneField(
        'users.Usuario',
        on_delete=models.PROTECT,
        db_column='usuario_id',
        related_name='poliza',
    )

    policy_number = models.CharField(max_length=100)
    insurer = models.CharField(max_length=100)
    policy_start_date = models.DateField()

    # La confirma la aseguradora. Si coincide con Usuario.birth_date, lo
    # ganado en la cuenta base cuenta retroactivo; si no, se arranca en cero.
    birth_date_confirmada = models.DateField(
        null=True,
        blank=True
    )

    # Por defecto pendiente: una póliza recién vinculada todavía no está
    # confirmada por la aseguradora.
    estado_verificacion = models.CharField(
        max_length=10,
        choices=EstadoVerificacion.choices,
        default=EstadoVerificacion.PENDIENTE,
    )

    fecha_vinculacion = models.DateTimeField(auto_now_add=True)
    fecha_verificacion = models.DateTimeField(
        null=True,
        blank=True
    )

    def __str__(self):
        return f"{self.insurer} {self.policy_number} - {self.estado_verificacion}"
