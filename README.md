# StudyBuddy-Django-App

[![CI](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/AAdewunmi/StudyBuddy-Study-Planner-Project/branch/main/graph/badge.svg)](https://codecov.io/gh/AAdewunmi/StudyBuddy-Study-Planner-Project)
[![Python](https://img.shields.io/badge/python-3.13-blue?logo=python&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/Dockerfile)
[![Django](https://img.shields.io/badge/django-5.x-092E20?logo=django&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/requirements.txt)
[![PostgreSQL](https://img.shields.io/badge/postgresql-16-4169E1?logo=postgresql&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/docker-compose.yml)
[![Docker](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/docker-compose.yml)
[![Code style: Black, Ruff](https://img.shields.io/badge/code%20style-black%20%7C%20ruff-black)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/pyproject.toml)
[![License](https://img.shields.io/github/license/AAdewunmi/StudyBuddy-Study-Planner-Project)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/LICENSE)

StudyBuddy-Django-App is a production-minded Django SaaS MVP for study
productivity. It lets authenticated users create study sessions, capture notes,
review their own study history, and see personal dashboard metrics from stored
data.

The repository is focused on a small, maintainable Django product foundation:
email-first authentication, user-owned study workflows, strict ownership
boundaries, a service-backed dashboard, PostgreSQL persistence, and pytest
coverage.

StudyBuddy is not a learning management system, classroom administration
platform, course marketplace, or general-purpose chatbot.

## Current Capabilities

- `StudySession` and `StudyNote` domain models.
- Email-first signup, login, logout, and profile flows.
- Role-aware access helpers through `user.studybuddy_roles`.
- Owner-scoped session list, create, detail, and update workflows.
- Note create, update, and delete workflows scoped through parent session
  ownership.
- Selector helpers for user-scoped session and note queries.
- Service helpers for dashboard aggregate metrics.
- A data-backed dashboard that renders prepared metrics and recent activity.
- Strict custom design-system templates using `static/css/theme.css`, not
  Bootstrap visual classes.

## Tech Stack

- Python 3.13 in Docker
- Django 5.x
- PostgreSQL 16
- pytest and pytest-django
- factory_boy
- django-environ
- Black and Ruff
- Custom Django template design system in `static/css/theme.css`
- Docker Compose

## Quick Start

Create the local environment file, start the Docker-backed stack, apply
migrations, then open the app.

```bash
cp .env.example .env
docker compose up -d --build
docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local
```

The app runs at:

```text
http://localhost:8000
```

## Local Setup

Run the Docker-backed local stack after creating `.env`.

```bash
docker compose up -d --build
```

Run checks inside the web container.

```bash
docker compose exec -T web python manage.py check --settings=config.settings.local
docker compose exec -T web python manage.py makemigrations study_sessions --check --dry-run --settings=config.settings.local
docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local
docker compose exec -T web python -m black . --check
docker compose exec -T web python -m ruff check .
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q
```

Host-side pytest also uses PostgreSQL. When running from a local Python
environment, point the test settings at Docker Compose's published database
port:

```bash
TEST_DATABASE_URL=postgres://studybuddy:studybuddy@localhost:5432/studybuddy_test python3 -m pytest --cov=apps --cov=config --cov-report=term-missing -q
```

Run the dashboard/session verification runbook.

```bash
./docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
```

## Environment Settings

StudyBuddy isolates environment behavior with explicit settings modules:

- `config.settings.local` is for Docker-backed local development.
- `config.settings.test` is for tests and CI, using PostgreSQL.
- `config.settings.production` is for deployment and requires production
  environment variables.

Docker Compose runs the app with `config.settings.local`. CI and local test
commands use `config.settings.test`.

## Architecture Notes

The main project documentation is:

- [Architecture](docs/architecture.md)
- [Domain model](docs/domain-model.md)
- [Design system](docs/design-system.md)
- [Operational runbook](RUNBOOK.md)
- [Sprint 2 canonical implementation outline](docs/studybuddy-sprint-2-canonical-implementation-outline.md)

The completed Sprint 2 outline records the implementation history. The README
keeps the current runtime shape and verification path front and center.

## Verification Baseline

The current Sprint 2 dashboard and sessions verification command is:

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests apps/sessions/tests -q
```

Expected current receipt:

```text
64 passed
```

The full local suite should also pass:

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q
```

## Core Routes

- `home` -> `/`
- `users:signup` -> `/users/signup/`
- `users:login` -> `/users/login/`
- `users:logout` -> `/users/logout/`
- `users:profile` -> `/users/profile/`
- `dashboard:index` -> `/dashboard/`
- `sessions:list` -> `/sessions/`
- `sessions:create` -> `/sessions/new/`
- `sessions:detail` -> `/sessions/<pk>/`
- `sessions:update` -> `/sessions/<pk>/edit/`
- `sessions:add_note` -> `/sessions/<pk>/notes/new/`
- `sessions:update_note` -> `/sessions/<pk>/notes/<note_pk>/edit/`
- `sessions:delete_note` -> `/sessions/<pk>/notes/<note_pk>/delete/`

## Repository Structure

```text
StudyBuddy-Study-Planner-Project/
    apps/
        dashboard/       Dashboard view, context service, and metrics tests.
        roles/           Role model and user-role relationships.
        sessions/        Study sessions, notes, selectors, services, and tests.
        users/           Custom user model, auth forms, profile, and user URLs.
    config/
        settings/        Base, local, test, and production Django settings.
        urls.py          Project URL routing.
        asgi.py          ASGI application entrypoint.
        wsgi.py          WSGI application entrypoint.
    docs/                Architecture, domain, design, setup, and runbooks.
    static/css/theme.css Project-owned design system styles.
    templates/           Base, dashboard, session, user, and public templates.
    tests/               Cross-app pytest coverage.
    Dockerfile           Container image definition.
    docker-compose.yml   Local PostgreSQL-backed development stack.
    manage.py            Django management command entrypoint.
    pyproject.toml       Project metadata and tool configuration.
    pytest.ini           Pytest and Django test configuration.
    RUNBOOK.md           Operational runbook for local checks and handoff.
    requirements.txt     Python dependency list.
```

## CI Coverage

CI generates `coverage.xml` with `pytest-cov` and uploads it to Codecov with
the `CODECOV_TOKEN` GitHub Actions secret. The Codecov repository must be active
in Codecov before uploads will be accepted.
