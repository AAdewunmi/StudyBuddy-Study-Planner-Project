# StudyBuddy Django App

[![CI](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/AAdewunmi/StudyBuddy-Study-Planner-Project/branch/main/graph/badge.svg)](https://codecov.io/gh/AAdewunmi/StudyBuddy-Study-Planner-Project)
[![Python](https://img.shields.io/badge/python-3.11%2B-blue?logo=python&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/pyproject.toml)
[![Django](https://img.shields.io/badge/django-5.x-092E20?logo=django&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/requirements.txt)
[![PostgreSQL](https://img.shields.io/badge/postgresql-16-4169E1?logo=postgresql&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/docker-compose.yml)
[![Docker](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/docker-compose.yml)
[![Code style: Black, Ruff](https://img.shields.io/badge/code%20style-black%20%7C%20ruff-black)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/pyproject.toml)
[![Tests](https://img.shields.io/badge/tests-pytest-brightgreen)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/pytest.ini)
[![License](https://img.shields.io/github/license/AAdewunmi/StudyBuddy-Study-Planner-Project)](https://github.com/AAdewunmi/StudyBuddy-Study-Planner-Project/blob/main/LICENSE)

StudyBuddy is a production-minded Django SaaS MVP for study productivity.

The product helps users register, manage study sessions, capture notes, review
personal progress, and generate deterministic AI/NLP insights from their own
study material.

This build is intentionally shaped like a believable early SaaS product rather
than a toy exercise. It uses clear app boundaries, PostgreSQL-backed
persistence, tested domain behaviour, role-aware access foundations, and
explainable NLP output.

StudyBuddy is not a learning management system, classroom administration
platform, course marketplace, or general-purpose chatbot.

## Current Sprint Status

Sprint 3 adds the AI/NLP study insights feature.

Users can now:

- create study sessions
- add notes to sessions
- generate deterministic insights from those notes
- view summaries, keywords, confidence scores, and explanations
- revisit generated insights from a dedicated dashboard

## Sprint 3 Feature Contract

The AI/NLP insight feature analyses notes attached to one user-owned study
session. It stores a reusable `StudyInsight` containing an extractive summary,
ranked keywords, a confidence score, an explanation, and a SHA-256 source hash
derived from normalised note text.

The feature is deterministic by design. If the same session notes are analysed
again without changes, StudyBuddy reuses the existing insight for that
`session` and `source_hash` instead of creating a duplicate row.

The MVP boundary is intentionally narrow:

- no large language model or external AI API
- no background worker
- no uploaded-file analysis
- no cross-user or cross-account analysis
- no semantic embeddings, topic clustering, or recommendation engine
- no claim that confidence is a probability or factual correctness score

The detailed product and technical contract lives in
[docs/ai-nlp-contract.md](docs/ai-nlp-contract.md).

## Current Capabilities

- `StudySession` and `StudyNote` domain models.
- `StudyInsight` persistence for deterministic note insights.
- Email-first signup, login, logout, and profile flows.
- Role-aware access helpers through `user.studybuddy_roles`.
- Owner-scoped session list, create, detail, and update workflows.
- Note create, update, and delete workflows scoped through parent session
  ownership.
- Deterministic AI/NLP pipeline for source hashing, keyword extraction,
  extractive summaries, confidence scoring, and explanations.
- Idempotent insight generation for unchanged note text.
- Insights dashboard scoped to the authenticated user.
- Selector helpers for user-scoped session and note queries.
- Service helpers for dashboard aggregate metrics.
- A data-backed dashboard that renders prepared metrics and recent activity.
- Strict custom design-system templates using `static/css/theme.css`, not
  Bootstrap visual classes.

## Tech Stack

- Python 3.11+ supported by project metadata
- Python 3.13 in Docker
- Django 5.x
- PostgreSQL 16
- Django templates
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

Run the Sprint 3 insight verification runbook.

```bash
./docs/sprint-runbook/sprint-3/sprint-3-day-4.sh
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
- [AI/NLP contract](docs/ai-nlp-contract.md)
- [Operational runbook](RUNBOOK.md)
- [Canonical implementation outline](docs/studybuddy-canonical-implementation-outline.md)

The canonical implementation outline is the central implementation source of
truth. The AI/NLP contract records the deterministic Sprint 3 insight behaviour.
The README keeps the current runtime shape and verification path front and
center.

## Verification Baseline

The current Sprint 3 insights verification command is:

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/insights -q
```

This command proves the feature contract at the test level: model persistence,
source hashing, keyword extraction, extractive summarisation, confidence
scoring, explanation text, idempotent generation, owner-only access, dashboard
visibility, and view-level route behaviour are covered by `apps/insights/tests`.

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
- `insights:list` -> `/insights/`
- `insights:generate` -> `/insights/sessions/<session_id>/generate/`

## Repository Structure

```text
StudyBuddy-Study-Planner-Project/
    apps/
        dashboard/       Dashboard view, context service, and metrics tests.
        insights/        Deterministic AI/NLP insights, selectors, and tests.
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
    templates/           Base, dashboard, insight, session, user, and public templates.
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
