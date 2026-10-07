import uuid

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction

from rest_framework import serializers

from services import cuentas
from services.edad import problema_con_la_fecha_de_nacimiento

from .models import Usuario


User = get_user_model()


class RegistroSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
    )
    birth_date = serializers.DateField()

    def validate_username(self, value):
        # Sin distinguir mayúsculas, y también contra el correo de las cuentas de Google/Apple.
        if cuentas.correo_en_uso(value):
            raise serializers.ValidationError(
                "Este nombre de usuario ya existe."
            )
        return value

    def validate_birth_date(self, value):
        # La edad sale de esta fecha (FCmáx, bono 60+): una fecha futura daría
        # una edad negativa y rompería el cálculo de puntos. Solo de 18 a 120 años
        # (services/edad.py); el login con Google y Apple tiene que usar la misma regla.
        problema = problema_con_la_fecha_de_nacimiento(value)
        if problema is not None:
            raise serializers.ValidationError(problema)
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
        try:
            with transaction.atomic():
                user = User.objects.create_user(
                    username=validated_data["username"],
                    password=validated_data["password"],
                )
        except IntegrityError:
            # Dos registros del mismo correo a la vez: la base deja pasar a uno.
            raise serializers.ValidationError({"username": ["Este nombre de usuario ya existe."]})

        # El identificador público lo genera el servidor: el cliente no lo
        # elige, así no puede repetirlo ni adivinar el de otra persona.
        Usuario.objects.create(
            user=user,
            usuario_id=str(uuid.uuid4()),
            birth_date=validated_data["birth_date"],
        )

        return user
