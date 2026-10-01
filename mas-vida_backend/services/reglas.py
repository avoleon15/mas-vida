from datetime import date

from Apps.poincs.models import VersionRegla


class SinVersionRegla(Exception):
    pass


def version_regla_vigente(fecha: date) -> VersionRegla:
    """Versión de reglas con la que se sella cada fila de los ledgers."""
    version = (
        VersionRegla.objects
        .filter(vigente_desde__lte=fecha)
        .order_by("-vigente_desde")
        .first()
    )
    if version is None:
        raise SinVersionRegla(f"No hay versión de regla vigente al {fecha}")
    return version
