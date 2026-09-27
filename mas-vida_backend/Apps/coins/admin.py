from django.contrib import admin
from .models import MonedaLedger, Premio, Canje

# Register your models here.
admin.site.register([MonedaLedger,Premio,Canje])
