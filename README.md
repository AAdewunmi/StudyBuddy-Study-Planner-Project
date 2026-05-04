# StudyBuddy-Django-App

[![CI](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/AAdewunmi/StudyBuddy-Study-Planner-Project/branch/main/graph/badge.svg)](https://codecov.io/gh/AAdewunmi/StudyBuddy-Study-Planner-Project)
[![Python](https://img.shields.io/badge/python-3.13-blue?logo=python&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/Dockerfile)
[![Django](https://img.shields.io/badge/django-5.x-092E20?logo=django&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/requirements.txt)
[![PostgreSQL](https://img.shields.io/badge/postgresql-16-4169E1?logo=postgresql&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/docker-compose.yml)
[![Docker](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/docker-compose.yml)
[![Code style: Black, Ruff, isort](https://img.shields.io/badge/code%20style-black%20%7C%20ruff%20%7C%20isort-black)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/pyproject.toml)
[![License](https://img.shields.io/github/license/AAdewunmi/StudyBuddy-Study-Planner-Project)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/LICENSE)

StudyBuddy-Django-App is a production-minded SaaS MVP for study productivity.

The product helps users register, manage study sessions, capture notes, review personal progress, and generate lightweight deterministic AI/NLP insights from their own study material.

StudyBuddy is not a learning management system, a classroom administration platform, a course marketplace, or a general-purpose AI chatbot. The repository is focused on a small, maintainable Django product foundation that can grow into study planning, notes, progress tracking, and lightweight insight features.

Sprint 1 establishes the product foundation, Django architecture, PostgreSQL configuration, custom user model, roles foundation, authentication workflow, protected dashboard shell, and first test suite.

## Sprint 1 scope

Sprint 1 delivers:

- Django project structure under `config/`
- Split settings for base, local, test, and production
- Environment-driven configuration
- PostgreSQL local persistence configuration
- Email-first custom user model
- Role model and user-role relationship
- Signup, login, logout, and profile views
- Bootstrap-backed template shell
- Protected dashboard
- Pytest, pytest-django, and factory_boy test baseline
- Practical architecture and setup documentation

Sprint 1 does not yet implement study sessions, notes, dashboard metrics, AI/NLP insights, or deployment. Those are delivered in later sprints.

## Tech stack

- Python 3.11+
- Django 5.x
- PostgreSQL
- pytest
- pytest-django
- factory_boy
- Bootstrap 5
- django-environ

## Repository Structure

```text
StudyBuddy-Study-Planner-Project/
    apps/
        dashboard/       Authenticated dashboard shell.
        roles/           Role model and user-role relationships.
        users/           Custom user model, auth forms, profile, and user URLs.
    config/
        settings/        Environment-specific Django settings.
        urls.py          Project URL routing.
        asgi.py          ASGI application entrypoint.
        wsgi.py          WSGI application entrypoint.
    docs/                Architecture and project documentation.
    static/              Project static assets.
    templates/           Shared and app-level Django templates.
    tests/               Pytest model and view tests.
    Dockerfile           Container image definition.
    docker-compose.yml   Local PostgreSQL-backed development stack.
    manage.py            Django management command entrypoint.
    pyproject.toml       Project metadata and tool configuration.
    pytest.ini           Pytest and Django test configuration.
    requirements.txt     Python dependency list.
```

## Local setup

Run the Docker-backed local stack.

```bash
docker compose up --build
```

Run checks inside the web container.

```bash
docker compose exec -T web python manage.py check
docker compose exec -T web python manage.py makemigrations --check --dry-run
docker compose exec -T web python -m black . --check
docker compose exec -T web python -m isort . --check-only
docker compose exec -T web python -m ruff check .
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q
```

## Environment settings

StudyBuddy isolates environment behaviour with explicit settings modules:

- `config.settings.local` is for Docker-backed local development.
- `config.settings.test` is for tests and CI, and uses PostgreSQL.
- `config.settings.production` is for deployment and requires production environment variables.

Docker Compose runs the app with `config.settings.local`. CI runs checks and tests with `config.settings.test`.

## CI coverage

CI generates `coverage.xml` with `pytest-cov` and uploads it to Codecov with the `CODECOV_TOKEN` GitHub Actions secret.
The Codecov repository must be active in Codecov before uploads will be accepted.
