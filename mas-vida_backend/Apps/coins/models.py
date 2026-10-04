import calendar
from datetime import timedelta

from django.core.exceptions import ValidationError
from django.db import models
from Apps.core.models import ModeloBase, SoloAgregar, UserIdBase

# Create your models here.
class MonedaLedger(SoloAgregar, UserIdBase):
    class Tipo(models.TextChoices):
        OBJETIVO_CUMPLIDO = 'objetivo_cumplido', 'Objetivo cumplido'
        LIGA_MENSUAL = 'liga_mensual', 'Liga mensual'
        CANJE = 'canje', 'Canje'
        EXPIRACION = 'expiracion', 'Expiracion'
        AJUSTE_MANUAL = 'ajuste_manual', 'Ajuste manual'
    
    cantidad = models.IntegerField()
    tipo = models.CharField(
        max_length=50,
        choices=Tipo.choices,
    )
    fecha = models.DateField()
    fecha_expiracion = models.DateField(null=True, blank=True)
    creado_en = models.DateTimeField(auto_now_add=True)
    version_regla = models.ForeignKey(
        "poincs.VersionRegla",
        on_delete=models.PROTECT
    )

class Premio(ModeloBase):
    nombre = models.CharField(max_length=150)
    descripcion = models.TextField()
    costo_monedas = models.PositiveIntegerField()
    comercio_aliado = models.CharField(max_length=150)
    # Lo que muestra el catálogo (3 oct 2026). Todo se edita a mano en el admin.
    zona = models.CharField(max_length=100, default="Guatemala")
    categoria = models.CharField(max_length=100, blank=True, default="")
    detalle = models.TextField(blank=True, default="")
    condiciones = models.TextField(blank=True, default="")
    # Ruta del logo dentro de la app y color de fondo "#RRGGBB" detrás del logo
    # (solo los logos claros lo necesitan). Vacío = sin logo / fondo blanco.
    foto = models.CharField(max_length=255, blank=True, default="")
    fondo = models.CharField(max_length=7, blank=True, default="")
    # Un premio apagado deja de salir en el catálogo sin borrarlo: los cupones
    # ya canjeados siguen apuntando a él.
    activo = models.BooleanField(default=True)
    # Último día en que se puede canjear. Null = sin fecha.
    vigente_hasta = models.DateField(null=True, blank=True)


class Patrocinio(ModeloBase):
    """Una marca que compró visibilidad (4 oct 2026). Todo se edita en el admin.

    Hay tres extras de pago: patrocinar una SEMANA (paga un cupón a quien la
    completa), patrocinar La Liga de un MES (paga un cupón al podio) y
    DESTACAR un premio en el catálogo. La marca, el logo y el fondo salen del
    `premio` (el mismo comercio del catálogo); aquí van solo el periodo, el
    cupón y el color de acento.
    """

    class Tipo(models.TextChoices):
        SEMANA = 'semana', 'Semana'
        LIGA = 'liga', 'La Liga'
        DESTACADO = 'destacado', 'Premio destacado'

    tipo = models.CharField(max_length=10, choices=Tipo.choices)
    premio = models.ForeignKey(Premio, on_delete=models.PROTECT, related_name='patrocinios')
    # Semana: lunes y domingo. Liga: día 1 y último día del mes. Destacado:
    # cualquier rango. Los dos días son inclusivos.
    desde = models.DateField()
    hasta = models.DateField()
    # Lo que se lleva quien gana ("2x1 en sushi"). Obligatorio en semana y liga.
    cupon = models.CharField(max_length=150, blank=True, default="")
    # Color de los detalles de la marca, "#RRGGBB". Vacío = el azul de +Vida.
    acento = models.CharField(max_length=7, blank=True, default="")
    # Fotos que rota el carrusel de la semana. Vacío = solo el logo.
    fotos = models.JSONField(default=list, blank=True)
    # Apagarlo lo quita de la app sin borrarlo (los cupones ya ganados apuntan a él).
    activo = models.BooleanField(default=True)

    class Meta:
        constraints = [
            # Una sola marca por semana y por mes de La Liga.
            models.UniqueConstraint(
                fields=['tipo', 'desde'],
                condition=models.Q(tipo__in=['semana', 'liga']),
                name='uq_patrocinio_tipo_desde',
            ),
        ]

    def __str__(self):
        return f"{self.get_tipo_display()} {self.desde} - {self.premio.comercio_aliado}"

    def clean(self):
        if self.desde is None or self.hasta is None:
            return
        if self.hasta < self.desde:
            raise ValidationError({"hasta": "Tiene que ser el mismo día o después de «desde»."})
        if self.tipo == self.Tipo.SEMANA:
            if self.desde.weekday() != 0 or self.hasta != self.desde + timedelta(days=6):
                raise ValidationError(
                    "Una semana va de lunes a domingo: «desde» es el lunes y «hasta» el domingo."
                )
        elif self.tipo == self.Tipo.LIGA:
            ultimo = calendar.monthrange(self.desde.year, self.desde.month)[1]
            if self.desde.day != 1 or (self.hasta.year, self.hasta.month, self.hasta.day) != (
                self.desde.year, self.desde.month, ultimo,
            ):
                raise ValidationError(
                    "Un mes de La Liga va del día 1 al último día del mes."
                )
        if self.tipo in (self.Tipo.SEMANA, self.Tipo.LIGA):
            if not self.cupon.strip():
                raise ValidationError({"cupon": "Hace falta el texto del cupón que se gana."})
            if self.premio_id and not self.premio.foto:
                raise ValidationError({"premio": "El comercio necesita logo (campo foto del premio)."})
        if not isinstance(self.fotos, list) or not all(isinstance(f, str) for f in self.fotos):
            raise ValidationError({"fotos": "Tiene que ser una lista de rutas (texto)."})

class Canje(UserIdBase):
    class Estado(models.TextChoices):
        ACTIVO = 'activo', 'Activo'
        USADO = 'usado', 'Usado'
        EXPIRADO = 'expirado', 'Expirado'

    premio = models.ForeignKey(
        Premio,
        on_delete=models.PROTECT
    )
    costo_monedas = models.PositiveIntegerField()
    fecha_canje  = models.DateTimeField()
    fecha_expiracion_cupon = models.DateField()
    estado = models.CharField(
        max_length=50,
        choices=Estado.choices
    )

    class Origen(models.TextChoices):
        TIENDA = 'tienda', 'Tienda'      # lo compró con monedas
        SEMANA = 'semana', 'Semana'      # semana patrocinada
        LIGA = 'liga', 'La Liga'         # podio patrocinado

    # Lo que lee la caja del comercio. Único: dos cupones nunca comparten código.
    codigo = models.CharField(max_length=20, unique=True, null=True, blank=True)
    origen = models.CharField(max_length=10, choices=Origen.choices, default=Origen.TIENDA)
    # Dónde se ganó, si no se compró: "Semana 1", "La Liga de agosto".
    ganado_en = models.CharField(max_length=100, blank=True, default="")
    usado_en = models.DateTimeField(null=True, blank=True)
    # Cupón ganado por un patrocinio (4 oct 2026): de cuál salió y qué beneficio
    # dice. Vacío / nulo en los de la tienda, que usan el del premio.
    beneficio = models.CharField(max_length=150, blank=True, default="")
    patrocinio = models.ForeignKey(
        Patrocinio, null=True, blank=True, on_delete=models.PROTECT, related_name='cupones',
    )

    class Meta:
        constraints = [
            # Un patrocinio da un solo cupón por usuario: correr el cierre dos veces no duplica.
            models.UniqueConstraint(
                fields=['usuario', 'patrocinio'],
                condition=models.Q(patrocinio__isnull=False),
                name='uq_canje_usuario_patrocinio',
            ),
        ]

