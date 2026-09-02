from django.shortcuts import render
from django.db import transaction
from rest_framework.decorators import api_view 
from rest_framework.response import Response
from rest_framework import status

from Apps.users.models import Usuario
from .models import Muestra, MuestraBPM, Sesion

# Create your views here.


@api_view(['POST'])
def sync(request):
    payload = request.data
    usuario_id = payload.get('usuario_id')

    try:
        usuario = usuario_id.objects.get(usuario_id=usuario_id)
    except Usuario.DoesNotExist:
        return Response(
            {'mensaje': 'Falla al recibir payload'},
            status=status.HTTP_404_NOT_FOUND
        )

    return Response(
        {'mensaje': 'payload recibido'},
        status=status.HTTP_200_OK
    )   



