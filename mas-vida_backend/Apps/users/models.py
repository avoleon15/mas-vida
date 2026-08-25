from django.db import models
from django.contrib.auth.models import User

class Usuario(models.Model):
    user = models.OneToOneField(
        User, 
        on_delete=models.CASCADE
    )

birthdate = models.DateField()

policy_number = models.CharField(
    max_length=100
)

insurer = models.CharField(
    max_length=100
)

policy_start_date = models.DateField()

def __str__(self):
    return self.user.username

