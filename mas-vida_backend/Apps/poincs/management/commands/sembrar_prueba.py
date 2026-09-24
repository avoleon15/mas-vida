"""Carga un usuario de prueba con puntos para probar GET /api/v1/historial.

Uso:  python manage.py sembrar_prueba

Solo para desarrollo local. Se puede correr las veces que haga falta: si
el usuario o los puntos ya existen, los actualiza en vez de duplicarlos.
"""
from datetime import date, timedelta

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand
from django.db import transaction

from Apps.poincs.models import Ledger, VersionRegla
from Apps.users.models import Usuario

USERNAME = "prueba"
PASSWORD = "masvida123"

# (puntos por pasos, puntos por intensidad) de los ultimos 10 dias, del
# mas viejo al de hoy. Salen de las tablas de CLAUDE.md: pasos da 0, 25,
# 50 o 100; intensidad 0, 50, 100 o 150. El tope diario es 200.
DIAS = [
    (25, 0),
    (50, 50),
    (0, 0),
    (100, 50),
    (100, 150),  # 250 brutos -> se acreditan 200 con tope_diario_aplicado
    (50, 0),
    (25, 100),
    (100, 100),  # exactamente 200: NO cuenta como recorte
    (50, 50),
    (25, 0),
]

TOPE_DIARIO = 200


class Command(BaseCommand):
    help = "Crea el usuario 'prueba' con 10 dias de puntos para probar el historial."

    @transaction.atomic
    def handle(self, *args, **options):
        version, _ = VersionRegla.objects.get_or_create(
            version=1,
            defaults={"vigente_desde": date(2026, 1, 1)},
        )

        user, creado = User.objects.get_or_create(username=USERNAME)
        user.set_password(PASSWORD)
        user.save()

        usuario, _ = Usuario.objects.get_or_create(
            user=user,
            defaults={
                "usuario_id": "prueba-1",
                "birth_date": date(1995, 5, 10),
                "policy_number": "POL-PRUEBA-001",
                "insurer": "Aseguradora de prueba",
                "policy_start_date": date(2026, 1, 1),
            },
        )

        hoy = date.today()
        for i, (pasos, intensidad) in enumerate(DIAS):
            fecha = hoy - timedelta(days=len(DIAS) - 1 - i)
            brutos = pasos + intensidad
            Ledger.objects.update_or_create(
                usuario=usuario,
                fecha=fecha,
                tipo="puntos_diarios",
                defaults={
                    "puntos": min(brutos, TOPE_DIARIO),
                    "puntos_pasos": pasos,
                    "puntos_intensidad": intensidad,
                    "tope_diario_aplicado": brutos > TOPE_DIARIO,
                    "version_regla": version,
                },
            )

        self.stdout.write(self.style.SUCCESS(
            f"Listo: usuario '{USERNAME}' (contrasena '{PASSWORD}') "
            f"con {len(DIAS)} dias de puntos."
        ))
