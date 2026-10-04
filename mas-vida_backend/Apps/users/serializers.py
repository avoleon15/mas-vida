import uuid

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction
from django.utils import timezone

from rest_framework import serializers

from .models import Usuario


User = get_user_model()


def validar_fecha_nacimiento(value):
    # La edad sale de esta fecha (FCmáx, bono 60+): una fecha futura daría
    # una edad negativa y rompería el cálculo de puntos.
    if value > timezone.localdate():
        raise serializers.ValidationError(
            "La fecha de nacimiento no puede ser futura."
        )
    return value


class RegistroSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )
    birth_date = serializers.DateField()

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError(
                "Este nombre de usuario ya existe."
            )
        return value

    def validate_birth_date(self, value):
        return validar_fecha_nacimiento(value)

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

        # El identificador público lo genera el servidor: el cliente no lo
        # elige, así no puede repetirlo ni adivinar el de otra persona.
        Usuario.objects.create(
            user=user,
            usuario_id=str(uuid.uuid4()),
            birth_date=validated_data["birth_date"],
        )

        return user


class LoginSocialSerializer(serializers.Serializer):
    # El token firmado que el proveedor le dio a la app.
    credencial = serializers.CharField(max_length=10_000, trim_whitespace=True)
    # Ni Google ni Apple la entregan: solo hace falta la primera vez.
    birth_date = serializers.DateField(required=False)
    # El que la app le pidió al proveedor al iniciar (protege contra reuso del token).
    # Sin recortar espacios: tiene que llegar idéntico al que se le dio al proveedor.
    nonce = serializers.CharField(max_length=200, required=False, trim_whitespace=False)

    def validate_birth_date(self, value):
        return validar_fecha_nacimiento(value)
