FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Junta los estilos del admin en staticfiles/ (whitenoise los sirve). DEBUG=true solo
# para este comando: sin él, la configuración exige SECRET_KEY y ALLOWED_HOSTS, que no
# existen al construir la imagen.
RUN DEBUG=true python manage.py collectstatic --noinput

# En el servidor el backend no corre como root: si alguien lograra entrar al proceso,
# no tendría permisos sobre el sistema.
RUN useradd --create-home --uid 1000 masvida && chown -R masvida /app
USER masvida

EXPOSE 8000

# gunicorn: el servidor para usuarios reales (runserver es solo para desarrollo).
# El número de procesos sale de WEB_CONCURRENCY (por defecto 3). En tu computadora,
# compose.yaml cambia este comando por runserver.
CMD ["sh", "-c", "exec gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers ${WEB_CONCURRENCY:-3} --timeout 60 --access-logfile -"]
