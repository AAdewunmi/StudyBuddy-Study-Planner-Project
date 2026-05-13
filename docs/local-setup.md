# Local Setup

This guide describes the Docker-backed local setup for StudyBuddy-Django-App.

## Requirements

- Docker Desktop or a compatible Docker daemon
- Docker Compose
- Git
- A shell that can run standard project commands

Python and PostgreSQL are provided by Docker. You do not need to create a local
virtual environment to run the app.

Manual local setup is not the supported path because the current setup has
Docker provide Python and PostgreSQL.

## Environment File

Create a local `.env` file from the example.

```bash
cp .env.example .env
```

The primary database setting is `DATABASE_URL`.

```text
DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local
```

Docker Compose also uses the PostgreSQL variables in `.env` to initialize the
database service.

## Start The Stack

Run the local app and PostgreSQL services.

```bash
docker compose up --build
```

The Django app is available at:

```text
http://localhost:8000
```

For detached mode, run:

```bash
docker compose up -d --build
```

## Verify Services

```bash
docker compose ps
```

The `db` service should be healthy, and the `web` service should be running.

## Run Django Checks

```bash
docker compose exec -T web python manage.py check --settings=config.settings.local
docker compose exec -T web python manage.py check --settings=config.settings.test
```

## Run Migrations

```bash
docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local
docker compose exec -T web python manage.py makemigrations study_sessions --check --dry-run --settings=config.settings.local
```

Expected output for an already-initialized local database:

```text
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, roles, sessions, study_sessions, users
Running migrations:
  No migrations to apply.
No changes detected in app 'study_sessions'
```

On a fresh PostgreSQL volume, `migrate` should apply Django and StudyBuddy
migrations and exit successfully. After that, the `makemigrations
study_sessions --check --dry-run` command should still report no changes.

## Run Formatting And Linting

```bash
docker compose exec -T web python -m black . --check
docker compose exec -T web python -m ruff check .
```

`ruff` is the current import-order gate used by the project checks.

## Run Tests

Run the full test suite with isolated test settings.

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q
```

Run the Sprint 2 dashboard and sessions suite.

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests apps/sessions/tests -q
```

Expected current receipt:

```text
64 passed
```

Run tests with coverage, matching CI.

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --cov=apps --cov=config --cov-report=xml -q
```

## Run Sprint Verification Runbooks

The completed Sprint 2 dashboard/session verification is:

```bash
./docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
```

The canonical Sprint 2 implementation outline is:

```text
docs/studybuddy-sprint-2-canonical-implementation-outline.md
```

## Stop The Stack

```bash
docker compose down
```

To remove the local PostgreSQL volume as well:

```bash
docker compose down -v
```

Only remove the volume when you intentionally want to delete local database
data.
