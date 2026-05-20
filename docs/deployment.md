# Deployment

StudyBuddy is configured for deployment as a Docker-backed Django application
with managed PostgreSQL.

Live MVP URL:

```text
https://studybuddy-django-app.onrender.com
```

Repository:

```text
https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project
```

## Runtime Shape

The production container is defined by:

```text
Dockerfile
```

The image uses:

- Python 3.13 slim
- `config.settings.production`
- Gunicorn
- WhiteNoise compressed manifest static files
- `PORT`, defaulting to `8000`

The container command is:

```bash
gunicorn config.wsgi:application --bind 0.0.0.0:${PORT}
```

## Production Settings

Production settings live in:

```text
config/settings/production.py
```

Production settings are intentionally environment-driven. The application fails
fast if required production values are missing.

Required environment variables:

```text
DJANGO_SECRET_KEY
DJANGO_ALLOWED_HOSTS
DATABASE_URL
```

Recommended environment variables:

```text
DJANGO_SETTINGS_MODULE=config.settings.production
DJANGO_CSRF_TRUSTED_ORIGINS=https://studybuddy-django-app.onrender.com
DJANGO_SECURE_SSL_REDIRECT=True
DATABASE_SSL_REQUIRE=True
DJANGO_LOG_LEVEL=INFO
RELEASE_SHA=<deployment-release-sha>
```

Render or another deployment platform should provide `DATABASE_URL` from its
managed PostgreSQL service.

## Render Example

Example production values:

```text
DJANGO_SETTINGS_MODULE=config.settings.production
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=studybuddy-django-app.onrender.com
DJANGO_CSRF_TRUSTED_ORIGINS=https://studybuddy-django-app.onrender.com
DATABASE_URL=<provided-by-render-managed-postgresql>
DATABASE_SSL_REQUIRE=True
RELEASE_SHA=<render-release-sha>
```

Do not use `.env.example` credentials in production. They are local-only
placeholders for Docker Compose development.

## Static Files

Production static files use Django's `STORAGES` setting with:

```text
whitenoise.storage.CompressedManifestStaticFilesStorage
```

Before serving production traffic, verify static collection:

```bash
docker compose exec -T web env \
  DJANGO_SECRET_KEY='local-deploy-check-only-long-random-looking-secret-1234567890' \
  DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
  DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local \
  DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:8000,http://127.0.0.1:8000 \
  DATABASE_SSL_REQUIRE=False \
  python manage.py collectstatic --noinput --settings=config.settings.production
```

Expected local receipt:

```text
0 static files copied to '/app/staticfiles', 128 unmodified, 357 post-processed.
```

The exact copied/unmodified counts can change when static assets change.

## Health Check

StudyBuddy exposes a deployment health endpoint:

```text
GET /health/
```

Successful response:

```json
{
  "status": "ok",
  "service": "studybuddy",
  "release": "local",
  "checks": {
    "database": "ok"
  }
}
```

If the database check fails, the endpoint returns HTTP `503` with:

```json
{
  "status": "degraded",
  "service": "studybuddy",
  "release": "local",
  "checks": {
    "database": "unavailable"
  }
}
```

## Local Deployment Checks

Run a production-settings deployment check locally through Docker Compose:

```bash
docker compose exec -T web env \
  DJANGO_SECRET_KEY='local-deploy-check-only-long-random-looking-secret-1234567890' \
  DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
  DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local \
  DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:8000,http://127.0.0.1:8000 \
  DATABASE_SSL_REQUIRE=False \
  python manage.py check --deploy --settings=config.settings.production
```

Expected clean receipt:

```text
System check identified no issues (0 silenced).
```

Run the health endpoint test:

```bash
docker compose exec -T web env \
  DJANGO_SETTINGS_MODULE=config.settings.test \
  TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test \
  pytest tests/test_health_check.py -q
```

Expected receipt:

```text
3 passed
```

## CI Relationship

GitHub Actions validates the project with:

- Django system checks
- migration drift checks
- migrations
- Ruff
- Black
- isort
- Docker image build
- pytest with coverage
- Codecov upload

See [Continuous Integration](ci.md) for the full CI quality gate.
