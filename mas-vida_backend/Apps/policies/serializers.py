from rest_framework import serializers


class VincularPolizaSerializer(serializers.Serializer):
    """Lo que manda el usuario para vincular su póliza.

    El usuario NO viene en el cuerpo: sale del token (request.user).
    """

    policy_number = serializers.CharField(max_length=100)
    insurer = serializers.CharField(max_length=100)
    birth_date = serializers.DateField()
