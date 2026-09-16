from django.db import models

# Create your models here.
class Policy(models.Model):

    class Status(models.TextChoices):
        pass

    class PlanType(models.TextChoices):
        pass

