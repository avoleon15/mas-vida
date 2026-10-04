from django.db.models import Sum
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from Apps.objetivos.models import CumplimientoSemanal
from Apps.users.models import Usuario
from services import goals, monedas, patrocinios, polizas, premios
from services.tiempo import hoy

from .models import MonedaLedger, Premio

SIN_PERFIL = {"mensaje": "El usuario autenticado no tiene un perfil asociado."}


def _usuario(request):
    try:
        return request.user.usuario
    except Usuario.DoesNotExist:
        return None


def _o_none(texto):
    return texto or None


def _fecha(valor):
    return valor.isoformat() if valor else None


def _premio(premio, destacado=False):
    return {
        # Texto, como en el resto de ids que lee la app.
        "id": str(premio.pk),
        "nombre": premio.nombre,
        "zona": premio.zona,
        "categoria": premio.categoria,
        "descripcion": premio.descripcion,
        "detalle": premio.detalle,
        "condiciones": premio.condiciones,
        "costo_monedas": premio.costo_monedas,
        # Último día para canjearlo; null si no tiene fecha.
        "vence": _fecha(premio.vigente_hasta),
        "foto": _o_none(premio.foto),
        "fondo": _o_none(premio.fondo),
        # El comercio compró visibilidad: su tarjeta sale ancha en el mosaico.
        "destacado": destacado,
    }


def _cupon(canje, fecha):
    estado = premios.estado_de(canje, fecha)
    vence = canje.fecha_expiracion_cupon
    return {
        "id": str(canje.pk),
        "comercio": canje.premio.comercio_aliado,
        # Los que se ganaron por un patrocinio traen el cupón de la marca.
        "beneficio": canje.beneficio or canje.premio.descripcion,
        "codigo": canje.codigo,
        "origen": canje.origen,
        "canjeado": timezone.localtime(canje.fecha_canje).date().isoformat(),
        "vence": vence.isoformat(),
        "dias_para_vencer": max((vence - fecha).days, 0) if estado == premios.ACTIVO else 0,
        "estado": estado,
        "foto": _o_none(canje.premio.foto),
        "fondo": _o_none(canje.premio.fondo),
        # Los que se ganaron no costaron monedas.
        "costo_monedas": canje.costo_monedas if canje.origen == canje.Origen.TIENDA else None,
        "ganado_en": _o_none(canje.ganado_en),
        "usado_el": _fecha(timezone.localtime(canje.usado_en).date()) if canje.usado_en else None,
    }


@api_view(["GET"])
def saldo_monedas(request):
    """Saldo de monedas del usuario y lo que la app necesita para mostrarlo.

    `vence` es el domingo en que cierra la season: ese día todavía se pueden
    usar, y al día siguiente el saldo vuelve a 0. `aviso_fin_de_season` se
    pone en true desde 7 días antes. `puede_canjear` es false sin póliza
    verificada: las monedas se ganan igual, pero no se gastan.
    """
    usuario = _usuario(request)
    if usuario is None:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)

    fecha = hoy()
    season = goals.season_de(fecha)
    ganadas = MonedaLedger.objects.filter(
        usuario=usuario,
        cantidad__gt=0,
        fecha__range=(season.fecha_inicio, season.fecha_fin),
    ).aggregate(total=Sum("cantidad"))["total"] or 0
    completas = CumplimientoSemanal.objects.filter(
        usuario=usuario,
        cumplido=True,
        objetivo_semanal__fecha_inicio__range=(season.fecha_inicio, season.fecha_fin),
    ).count()

    return Response({
        "saldo": monedas.saldo(usuario, fecha),
        "vence": monedas.fin_de_season(fecha).isoformat(),
        "dias_para_cierre": monedas.dias_para_fin_de_season(fecha),
        "aviso_fin_de_season": monedas.aviso_fin_de_season(fecha),
        "puede_canjear": polizas.tiene_poliza_verificada(usuario),
        "season": {
            "numero": season.numero,
            "anio": season.anio,
            "monedas_ganadas": ganadas,
            "semanas_completas": completas,
        },
    })


@api_view(["GET"])
def catalogo(request):
    """Premios que se pueden canjear hoy, con sus categorías para el filtro.

    El catálogo se ve completo con o sin póliza; lo que cambia es que sin
    póliza verificada el canje responde 403 (la app muestra el candado).
    """
    if _usuario(request) is None:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)

    lista = premios.catalogo()
    vendidos = patrocinios.destacados(hoy())
    categorias = sorted({p.categoria for p in lista if p.categoria})
    return Response({
        "categorias": ["Todos", *categorias],
        "premios": [_premio(p, p.pk in vendidos) for p in lista],
    })


@api_view(["POST"])
def canjear_premio(request, premio_id):
    """Canjea un premio con monedas. Devuelve el cupón y el saldo que queda.

    403 `poliza_no_verificada`, 404 si el premio no existe, 409
    `premio_no_disponible` (apagado o fuera de fecha) y 409
    `saldo_insuficiente`. Nunca se descuenta sin crear el cupón.
    """
    usuario = _usuario(request)
    if usuario is None:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)

    premio = Premio.objects.filter(pk=premio_id).first()
    if premio is None:
        return Response({"mensaje": "Ese premio no existe."}, status=status.HTTP_404_NOT_FOUND)

    try:
        canje = premios.canjear(usuario, premio)
    except premios.SinPolizaVerificada:
        return Response(
            {
                "error": "poliza_no_verificada",
                "mensaje": "Para canjear premios necesitas tu póliza verificada.",
            },
            status=status.HTTP_403_FORBIDDEN,
        )
    except premios.PremioNoDisponible:
        return Response(
            {"error": "premio_no_disponible", "mensaje": "Este premio ya no está disponible."},
            status=status.HTTP_409_CONFLICT,
        )
    except monedas.SaldoInsuficiente as e:
        return Response(
            {
                "error": "saldo_insuficiente",
                "mensaje": "No te alcanzan las monedas para este premio.",
                "saldo": e.saldo,
                "costo": premio.costo_monedas,
            },
            status=status.HTTP_409_CONFLICT,
        )

    fecha = hoy()
    return Response(
        {"cupon": _cupon(canje, fecha), "saldo": monedas.saldo(usuario, fecha)},
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET"])
def mis_cupones(request):
    """Todos los cupones del usuario (tienda, semanas y podios patrocinados).

    Primero los activos —el que vence antes arriba— y después los usados y
    vencidos. El estado y los días que faltan los calcula el servidor.
    """
    usuario = _usuario(request)
    if usuario is None:
        return Response(SIN_PERFIL, status=status.HTTP_403_FORBIDDEN)

    fecha = hoy()
    cupones = [_cupon(c, fecha) for c in premios.cupones_de(usuario, fecha)]
    return Response({
        "cupones": cupones,
        "por_usar": sum(1 for c in cupones if c["estado"] == premios.ACTIVO),
    })
