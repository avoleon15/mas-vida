from rest_framework import serializers


class VincularPolizaSerializer(serializers.Serializer):
    policy_number = serializers.CharField(max_length=100)
    insurer = serializers.CharField(max_length=100)
    policy_start_date = serializers.DateField()
