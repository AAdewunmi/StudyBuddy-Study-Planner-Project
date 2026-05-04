# StudyBuddy-Django-App

![CI Pipeline](https://img.shields.io/badge/CI-configured-blue)
![Python](https://img.shields.io/badge/Python-3.11%2B-blue)
![Django](https://img.shields.io/badge/Django-5.x-green)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-required-blue)
![Tests](https://img.shields.io/badge/tests-pytest-blue)
![Code Style](https://img.shields.io/badge/code%20style-ruff%20%2B%20black-black)
![Docker](https://img.shields.io/badge/Docker-ready-blue)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

StudyBuddy-Django-App is a production-minded SaaS MVP for study productivity.

The product helps users register, manage study sessions, capture notes, review personal progress, and generate lightweight deterministic AI/NLP insights from their own study material.

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
