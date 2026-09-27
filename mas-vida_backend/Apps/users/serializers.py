from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction

from rest_framework import serializers

from .models import Usuario


User = get_user_model()


class RegistroSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )
    usuario_id = serializers.CharField(max_length=100)
    birth_date = serializers.DateField()

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError(
                "Este nombre de usuario ya existe."
            )
        return value

    def validate_usuario_id(self, value):
        if Usuario.objects.filter(usuario_id=value).exists():
            raise serializers.ValidationError(
                "Este usuario_id ya existe."
            )
        return value

    def validate(self, attrs):
        user = User(username=attrs["username"])

        try:
            validate_password(attrs["password"], user)
        except DjangoValidationError as error:
            raise serializers.ValidationError(
                {"password": error.messages}
            )

        return attrs

    @transaction.atomic
    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data["username"],
            password=validated_data["password"],
        )

        Usuario.objects.create(
            user=user,
            usuario_id=validated_data["usuario_id"],
            birth_date=validated_data["birth_date"],
        )

        return user