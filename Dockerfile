# Container image for the StudyBuddy Django web service.
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=config.settings.production
ENV PORT=8000

WORKDIR /app

RUN addgroup --system django \
    && adduser --system --ingroup django django

COPY requirements.txt .

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

RUN DJANGO_SECRET_KEY=build-time-static-collection-only \
    DJANGO_ALLOWED_HOSTS=localhost \
    DATABASE_URL=postgres://studybuddy:studybuddy@localhost:5432/studybuddy \
    DATABASE_SSL_REQUIRE=False \
    DJANGO_DEFAULT_FROM_EMAIL=build@example.com \
    DJANGO_EMAIL_HOST=localhost \
    python manage.py collectstatic --noinput --settings=config.settings.production

RUN mkdir -p /app/staticfiles \
    && chown -R django:django /app

USER django

EXPOSE 8000

CMD ["sh", "-c", "gunicorn config.wsgi:application --bind 0.0.0.0:${PORT}"]
