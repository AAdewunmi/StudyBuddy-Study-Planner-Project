# Final Verification

This document records the final verification path for the StudyBuddy MVP. It
matches the current Docker-backed local workflow, GitHub Actions CI gate, and
Render Blueprint deployment contract.

## Release

Release tag:

```text
v0.1.0-mvp
```

Live MVP URL:

```text
https://studybuddy-django-app.onrender.com
```

## Scope

The verified MVP includes:

- email-first authentication and profile flows
- role-aware access helpers
- owner-scoped study sessions and notes
- authenticated dashboard metrics
- deterministic AI/NLP study insights
- PostgreSQL-backed local, test, and production settings
- Docker image build path
- Render Blueprint deployment through `render.yaml`
- `/health/` deployment health check
- WhiteNoise static file serving with manifest storage

## Required Local State

Run verification from the repository root with Docker running.

```bash
cp .env.example .env
make build
make up
make migrate
```

The local app should be available at:

```text
http://localhost:8000
```

## Local Verification

Run the local CI-style gate:

```bash
make ci
```

The `make ci` target runs:

```bash
python -m black . --check
python -m ruff check .
python manage.py check --settings=config.settings.local
python manage.py makemigrations --check --dry-run --settings=config.settings.local
python manage.py migrate --noinput --settings=config.settings.local
pytest -q
```

Run the hosted-CI-shaped coverage command inside Docker Compose:

```bash
docker compose exec -T web env \
  DJANGO_SETTINGS_MODULE=config.settings.test \
  TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test \
  pytest --cov=apps --cov=config --cov-report=xml -q
```

Current passing receipt:

```text
202 passed
Coverage XML written to file coverage.xml
```

Run focused health check verification:

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

## Hosted CI

GitHub Actions runs the hosted quality gate in:

```text
.github/workflows/ci.yml
```

The workflow runs:

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py migrate --noinput
python -m ruff check .
python -m black . --check
python -m isort . --check-only
docker build -t studybuddy-ci .
python -m pytest --cov=apps --cov=config --cov-report=xml -q
```

CI uploads `coverage.xml` to Codecov. The upload requires the
`CODECOV_TOKEN` GitHub Actions secret.

## Deployment Verification

Production deployment is defined in:

```text
render.yaml
```

The Render Blueprint defines:

- Docker web service `studybuddy-django-app`
- managed PostgreSQL database `studybuddy-postgres`
- `/health/` health check
- pre-deploy migration command
- non-secret production environment variables
- `DATABASE_URL` from the managed database connection string
- `DJANGO_SECRET_KEY` as `sync: false` for Render secret injection

The Docker image collects static assets during build. Verify the image path:

```bash
docker build -t studybuddy-render-check .
```

Run production settings deployment checks locally:

```bash
docker compose exec -T web env \
  DJANGO_SECRET_KEY='local-deploy-check-only-long-random-looking-secret-1234567890' \
  DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
  DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local \
  DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:8000,http://127.0.0.1:8000 \
  DATABASE_SSL_REQUIRE=False \
  python manage.py check --deploy --settings=config.settings.production
```

Expected receipt:

```text
System check identified no issues (0 silenced).
```

Verify static collection:

```bash
docker compose exec -T web env \
  DJANGO_SECRET_KEY='local-deploy-check-only-long-random-looking-secret-1234567890' \
  DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
  DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local \
  DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:8000,http://127.0.0.1:8000 \
  DATABASE_SSL_REQUIRE=False \
  python manage.py collectstatic --noinput --settings=config.settings.production
```

The receipt should mention copied, unmodified, or post-processed static files.

## Post-Deploy Verification

After Render finishes deploying the Blueprint, verify the live product rather
than only the local build.

Check the public home page:

```bash
curl -fsS https://studybuddy-django-app.onrender.com/ >/tmp/studybuddy-home.html
```

Expected result: the command exits successfully and returns the StudyBuddy home
page HTML.

Check the live health endpoint:

```bash
curl -fsS https://studybuddy-django-app.onrender.com/health/
```

Expected response:

```json
{
  "status": "ok",
  "service": "studybuddy",
  "release": "<deployed commit SHA>",
  "checks": {
    "database": "ok"
  }
}
```

Run a browser smoke test against the live URL:

1. Open `https://studybuddy-django-app.onrender.com/`.
2. Sign up with a test email address.
3. Confirm the app redirects to the authenticated dashboard.
4. Create a study session.
5. Add a note to the study session.
6. Generate an insight for the session.
7. Confirm the insight appears on the session detail page and insights list.
8. Log out.
9. Confirm protected pages redirect anonymous users to login.

The deployed product is release-verified only when the live health endpoint
reports `database: ok` and the browser smoke test passes against Render.

## Runtime Contract

Production requires:

```text
DJANGO_SETTINGS_MODULE=config.settings.production
DJANGO_SECRET_KEY
DJANGO_ALLOWED_HOSTS
DATABASE_URL
```

Render Blueprint-managed values include:

```text
DJANGO_SETTINGS_MODULE=config.settings.production
DJANGO_ALLOWED_HOSTS=studybuddy-django-app.onrender.com
DJANGO_CSRF_TRUSTED_ORIGINS=https://studybuddy-django-app.onrender.com
DATABASE_SSL_REQUIRE=true
DJANGO_SECURE_SSL_REDIRECT=true
DJANGO_SECURE_HSTS_SECONDS=31536000
DJANGO_LOG_LEVEL=INFO
```

Secrets and generated values are not committed:

```text
DJANGO_SECRET_KEY=<prompted by Render>
DATABASE_URL=<generated from studybuddy-postgres>
RENDER_GIT_COMMIT=<provided by Render for the deployed commit>
```

## Final Result

The MVP is verification-ready when:

- `make ci` passes locally
- hosted GitHub Actions CI passes
- Docker image build succeeds
- coverage command reports `202 passed`
- `coverage.xml` is generated
- production deployment check passes
- health check tests pass
- Render Blueprint is applied with secrets injected by Render
- live Render `/health/` returns `status: ok` and `database: ok`
- live browser smoke test passes
