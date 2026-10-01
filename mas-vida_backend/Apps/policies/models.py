from django.core.validators import MaxValueValidator
from django.db import models
from django.db.models import F, Q
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
    # Nulo hasta que la aseguradora confirma la póliza: es la fecha de inicio
    # de vigencia que trae su registro, y una póliza rechazada o que no existe
    # no la tiene.
    policy_start_date = models.DateField(null=True, blank=True)

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

    # Por qué se rechazó (no_existe, aseguradora_no_coincide, no_vigente,
    # fecha_nacimiento_no_coincide). Nulo si no está rechazada.
    motivo_rechazo = models.CharField(
        max_length=50,
        null=True,
        blank=True,
    )

    def __str__(self):
        return f"{self.insurer} {self.policy_number} - {self.estado_verificacion}"


class RegistroAseguradora(ModeloBase):
    """Documento SIMULADO de la aseguradora, solo para probar la verificación.

    Hace el papel de la base de datos de la aseguradora: las pólizas que
    existen de verdad. El usuario nunca la edita; se carga desde un CSV con
    `cargar_registro_aseguradora`. No es parte del diseño final: cuando haya
    una integración real con la aseguradora, esta tabla se reemplaza por su API
    (ver services/policy_verification.py).
    """

    class Estado(models.TextChoices):
        VIGENTE = 'vigente', 'Vigente'
        VENCIDA = 'vencida', 'Vencida'
        CANCELADA = 'cancelada', 'Cancelada'
        SUSPENDIDA = 'suspendida', 'Suspendida'

    numero_poliza = models.CharField(max_length=100, unique=True)
    aseguradora = models.CharField(max_length=100)
    nombre = models.CharField(max_length=100)
    apellido = models.CharField(max_length=100)
    fecha_nacimiento = models.DateField()
    plan = models.CharField(max_length=100)
    prima_mensual_gtq = models.DecimalField(max_digits=10, decimal_places=2)
    deducible_gtq = models.DecimalField(max_digits=10, decimal_places=2)
    coaseguro_pct = models.PositiveSmallIntegerField(
        validators=[MaxValueValidator(100)],
    )
    red = models.CharField(max_length=100)
    vigencia_inicio = models.DateField()
    vigencia_fin = models.DateField()
    estado = models.CharField(max_length=10, choices=Estado.choices)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=Q(vigencia_fin__gte=F('vigencia_inicio')),
                name='ck_registro_vigencia_fin_gte_inicio',
            ),
            models.CheckConstraint(
                condition=Q(coaseguro_pct__lte=100),
                name='ck_registro_coaseguro_0_100',
            ),
        ]

    def __str__(self):
        return f"{self.numero_poliza} - {self.aseguradora} ({self.estado})"
