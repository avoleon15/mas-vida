from django.db import models
from django.conf import settings


class Usuario(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE
    )

    usuario_id = models.CharField(
        max_length=100,
        unique=True
    )

    birth_date = models.DateField()

    policy_number = models.CharField(
        max_length=100
    )

    insurer = models.CharField(
        max_length=100
    )

    policy_start_date = models.DateField()

    def __str__(self):
        return self.usuario_id