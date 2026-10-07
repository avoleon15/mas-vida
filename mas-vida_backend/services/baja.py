"""Baja de cuenta: se borra lo personal y se conserva lo anónimo (etapa 14, 6 oct 2026).

Apple exige que la cuenta se pueda borrar desde la app (App Store 5.1.1(v)).

Qué se borra o se anonimiza:
- El acceso: el `username` (el correo) pasa a `baja-<usuario_id>`, el `email` y el
  nombre quedan vacíos, la contraseña queda inutilizable y la cuenta inactiva. Se
  cierran todas las sesiones. El correo queda libre para una cuenta nueva.
- La póliza se borra (con su nombre, número y datos de la aseguradora) y queda libre
  para otra cuenta.
- La fecha de nacimiento queda en el 1 de enero de su año: sirve para estadísticas por
  edad sin identificar a nadie.
- Los nombres de fuente y de dispositivo de las muestras (pueden decir "Apple Watch de
  Ana"). El puntaje no los usa: compara por bundle, modelo y fabricante.
- Se revoca el consentimiento y se sale de Tus Ligas.

Qué se conserva, ya sin nada que identifique a la persona: los puntos y las monedas
(los ledgers no se tocan), los resúmenes diarios, las muestras de salud, los cupones y
las tablas de ligas ya cerradas. El `usuario_id` es un identificador aleatorio que no
dice quién es.
"""
from datetime import date

from django.db import transaction
from django.utils import timezone

from Apps.activities.models import Muestra, MuestraBPM, Sesion
from Apps.liga.models import MiembroLigaAmigos
from Apps.policies.models import PolizaVinculada
from Apps.users.models import Usuario
from services import consentimiento, ligas, sesiones


def dar_de_baja(usuario, ahora=None) -> bool:
    """Da de baja la cuenta. Devuelve False si ya estaba dada de baja (no cambia nada)."""
    ahora = ahora or timezone.now()
    with transaction.atomic():
        usuario = Usuario.objects.select_for_update().select_related("user").get(pk=usuario.pk)
        if usuario.dado_de_baja_en is not None:
            return False

        for liga_id in MiembroLigaAmigos.objects.filter(usuario=usuario).values_list("liga_amigos_id", flat=True):
            ligas.salir(usuario, str(liga_id))

        PolizaVinculada.objects.filter(usuario=usuario).delete()

        for modelo in (Muestra, MuestraBPM, Sesion):
            modelo.objects.filter(usuario=usuario).update(fuente_nombre="", dispositivo_nombre=None)

        consentimiento.revocar(usuario, ahora)

        usuario.birth_date = date(usuario.birth_date.year, 1, 1)
        usuario.dado_de_baja_en = ahora
        usuario.save(update_fields=["birth_date", "dado_de_baja_en"])

        user = usuario.user
        user.username = f"baja-{usuario.usuario_id}"
        user.email = ""
        user.first_name = ""
        user.last_name = ""
        user.is_active = False
        user.set_unusable_password()
        user.save()

        sesiones.cerrar_todas(user)
    return True
