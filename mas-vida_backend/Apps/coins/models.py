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

