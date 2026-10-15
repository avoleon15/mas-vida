from django.db import models


class ModeloBase(models.Model):
    id = models.AutoField(primary_key=True)
    class Meta:
        abstract = True

class UserIdBase(ModeloBase):
    usuario = models.ForeignKey(
        "users.Usuario",
        on_delete=models.PROTECT      
    )
    class Meta:
        abstract = True



class FilaInmutable(Exception):
    """Se intentó editar o borrar una fila de un ledger (append-only)."""


class SoloAgregarQuerySet(models.QuerySet):
    """Bloquea `update()` y `delete()` en bloque: no pasan por `save()`."""

    def update(self, **kwargs):
        raise FilaInmutable(
            f"{self.model.__name__} es append-only: una corrección es una fila nueva."
        )

    def delete(self):
        raise FilaInmutable(
            f"{self.model.__name__} es append-only: sus filas no se borran."
        )


class SoloAgregar(models.Model):
    """Base de los ledgers (puntos y monedas): se crean filas, nunca se editan.

    Una corrección se asienta como una fila nueva (ajuste, expiración,
    retroactivo denegado). Esto convierte la regla en un candado real: editar
    una fila existente, actualizar o borrar en bloque lanzan FilaInmutable.
    """

    objects = SoloAgregarQuerySet.as_manager()

    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        if not self._state.adding:
            raise FilaInmutable(
                f"{type(self).__name__} es append-only: no se puede modificar una fila."
            )
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        raise FilaInmutable(
            f"{type(self).__name__} es append-only: sus filas no se borran."
        )
