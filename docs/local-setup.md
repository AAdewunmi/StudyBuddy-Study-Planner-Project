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

## Clean Clone

Clone the repository and enter the project root before running setup commands.

```bash
git clone https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project.git
cd StudyBuddy-Study-Planner-Project
```

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
make build
make up
```

The Django app is available at:

```text
http://localhost:8000
```

For detached mode, run:

```bash
make up
```

## Verify Services

```bash
docker compose ps
```

The `db` service should be healthy, and the `web` service should be running.

## Run Django Checks

```bash
make check
docker compose exec -T web python manage.py check --settings=config.settings.test
```

## Run Migrations

```bash
make migrate
make check-migrations
```

Expected output for an already-initialized local database:

```text
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, insights, roles, sessions, study_sessions, users
Running migrations:
  No migrations to apply.
No changes detected
```

On a fresh PostgreSQL volume, `migrate` should apply Django and StudyBuddy
migrations and exit successfully. After that, the `makemigrations --check
--dry-run` command should still report no changes.

## Run Formatting And Linting

```bash
make format-check
make lint
make isort
```

`make ci` runs Ruff, Black, and isort before building the Docker image and
running the coverage-producing test command.

## Run Tests

Run the full test suite with isolated test settings.

```bash
make test
```

Run the current insights suite.

```bash
make test-insights
```

Expected current receipt:

```text
69 passed
```

The full local suite should also pass. The exact count may change as coverage
grows:

```text
[number] passed
```

Run tests with coverage, matching CI.

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test pytest --cov=apps --cov=config --cov-report=xml -q
```

If you run pytest from a host-side Python environment instead of inside the
container, point the test settings at the PostgreSQL port published by Docker
Compose.

```bash
TEST_DATABASE_URL=postgres://studybuddy:studybuddy@localhost:5432/studybuddy_test python3 -m pytest --cov=apps --cov=config --cov-report=term-missing -q
```

## Run Verification Runbooks

The current release verification is:

```bash
./docs/sprint-runbook/sprint-4/sprint-4-day-4.sh
```

Historical sprint runbooks remain available under `docs/sprint-runbook/` for
traceability. For example, the completed dashboard/session verification is:

```bash
./docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
```

Historical sprint-era planning context is preserved in:

```text
docs/studybuddy-canonical-implementation-outline.md
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
