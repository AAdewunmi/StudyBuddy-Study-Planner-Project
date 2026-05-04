# Local Setup

This guide describes the Docker-backed local setup for StudyBuddy-Django-App.

## Requirements

- Docker Desktop or a compatible Docker daemon
- Docker Compose
- Git
- A shell that can run standard project commands

Python and PostgreSQL are provided by Docker. You do not need to create a local virtual environment to run the app.

## Environment File

Create a local `.env` file from the example.

```bash
cp .env.example .env
```

The primary database setting is `DATABASE_URL`.

```text
DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local
```

Docker Compose also uses the PostgreSQL variables in `.env` to initialize the database service.

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
docker compose exec -T web python manage.py migrate --noinput
docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.test
```

## Run Formatting And Linting

```bash
docker compose exec -T web python -m black . --check
docker compose exec -T web python -m isort . --check-only
docker compose exec -T web python -m ruff check .
```

## Run Tests

Run the test suite with isolated test settings.

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q
```

Run tests with coverage, matching CI.

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --cov=apps --cov=config --cov-report=xml -q
```

## Run The Sprint Verification Runbook

The Sprint 1 Day 1 runbook wraps the main setup checks into one executable script.

```bash
./docs/sprint-runbook/sprint-1/sprint-1-day-1
```

## Stop The Stack

```bash
docker compose down
```

To remove the local PostgreSQL volume as well:

```bash
docker compose down -v
```

Only remove the volume when you intentionally want to delete local database data.
