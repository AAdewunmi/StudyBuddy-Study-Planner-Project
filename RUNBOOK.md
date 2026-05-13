# StudyBuddy Runbook

This runbook describes the current operational workflow for
StudyBuddy-Django-App. It reflects the project after Sprint 2: authenticated
users can manage study sessions, capture notes, and view personal dashboard
metrics from stored data.

## Current Status

StudyBuddy is a Docker-backed Django SaaS MVP with:

- email-first custom users and authentication under `/users/`;
- role helpers exposed through `user.studybuddy_roles`;
- owner-scoped study sessions and notes under `/sessions/`;
- a data-backed authenticated dashboard under `/dashboard/`;
- user-scoped selectors in `apps/sessions/selectors.py`;
- aggregate session metrics in `apps/sessions/services.py`;
- dashboard context composition in `apps/dashboard/services.py`;
- custom template styling in `static/css/theme.css`;
- PostgreSQL-backed local, test, and production settings modules.

The canonical Sprint 2 implementation outline is:

```text
docs/studybuddy-sprint-2-canonical-implementation-outline.md
```

## Requirements

- Docker Desktop or a compatible Docker daemon
- Docker Compose
- Git
- A shell capable of running standard project commands

Python and PostgreSQL are provided by Docker for the supported local workflow.

## First-Time Local Setup

Run these commands from the repository root.

```bash
cp .env.example .env
docker compose up -d --build
docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local
```

Open the app at:

```text
http://localhost:8000
```

## Day-To-Day Local Workflow

Start or rebuild the local stack:

```bash
docker compose up -d --build
```

Check running services:

```bash
docker compose ps
```

Run the Django system check:

```bash
docker compose exec -T web python manage.py check --settings=config.settings.local
```

Apply migrations:

```bash
docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local
```

Confirm model migrations are clean:

```bash
docker compose exec -T web python manage.py makemigrations study_sessions --check --dry-run --settings=config.settings.local
```

Stop the stack:

```bash
docker compose down
```

Remove the local PostgreSQL volume only when intentionally deleting local data:

```bash
docker compose down -v
```

## Quality Gates

Run formatting, linting, and tests inside the web container.

```bash
docker compose exec -T web python -m black . --check
docker compose exec -T web python -m ruff check .
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q
```

`pytest.ini` already defaults to `config.settings.test`, but setting
`DJANGO_SETTINGS_MODULE` explicitly keeps Docker and CI commands easy to audit.

To auto-fix local formatting and import-order issues:

```bash
docker compose exec -T web python -m black .
docker compose exec -T web python -m ruff check . --fix
```

## Focused Verification

Run the current dashboard and sessions suite:

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests apps/sessions/tests -q
```

Expected current receipt:

```text
64 passed
```

Run the full Sprint 2 Day 5 verification runbook:

```bash
./docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
```

That script verifies:

- repository root and required Sprint 2 files;
- Docker/PostgreSQL startup;
- Django system checks and migrations;
- dashboard URL and template loading;
- session selectors and user-scoped ownership behavior;
- session metrics service calculations;
- dashboard context service output;
- anonymous dashboard redirects;
- dashboard empty and populated states;
- template aggregate boundaries;
- design-system template purity;
- dashboard and sessions tests.

## Core Routes

Current URL names and paths:

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

## Settings Modules

StudyBuddy uses explicit settings modules:

- `config.settings.local`: Docker-backed local development.
- `config.settings.test`: test and CI behavior.
- `config.settings.production`: deployment behavior.

Docker Compose runs with `config.settings.local`. Tests should run with
`config.settings.test`.

Production requires at least:

- `DJANGO_SETTINGS_MODULE=config.settings.production`
- `DJANGO_SECRET_KEY`
- `DJANGO_ALLOWED_HOSTS`
- `DATABASE_URL`

Production also supports:

- `DJANGO_SECURE_SSL_REDIRECT`
- `DJANGO_SECURE_HSTS_SECONDS`
- `DJANGO_SECURE_HSTS_INCLUDE_SUBDOMAINS`
- `DJANGO_SECURE_HSTS_PRELOAD`
- `DJANGO_CSRF_TRUSTED_ORIGINS`

## Architecture Rules

Keep these boundaries intact:

- Views should not duplicate ownership-sensitive filtering.
- Use `apps/sessions/selectors.py` for user-scoped session and note queries.
- Use `apps/sessions/services.py` for session aggregate metrics.
- Use `apps/dashboard/services.py` for dashboard context composition.
- Templates should render prepared values only.
- Templates should not calculate counts, sums, filters, or ownership rules.
- Templates should use classes from `static/css/theme.css`, not Bootstrap
  visual utility classes.

The dashboard template should render:

- `metrics.total_sessions`
- `metrics.completed_sessions`
- `metrics.total_minutes`
- `metrics.note_count`
- `recent_activity`

## Documentation Map

- `README.md`: project overview, quick start, verification, routes, structure.
- `docs/architecture.md`: app boundaries and service/query responsibilities.
- `docs/authentication.md`: auth routes, role relation, and access rules.
- `docs/domain-model.md`: users, roles, sessions, notes, selectors, services.
- `docs/design-system.md`: template and CSS design-system contract.
- `docs/local-setup.md`: Docker-backed local setup.
- `docs/studybuddy-sprint-2-canonical-implementation-outline.md`: Sprint 2
  implementation outline.
- `docs/sprint-runbook/sprint-2/sprint-2-day-5.sh`: complete Sprint 2
  dashboard/session verification script.

## Troubleshooting

If Docker commands fail, confirm Docker Desktop or the Docker daemon is running:

```bash
docker compose ps
```

If code changes do not appear in the running app, rebuild the web container:

```bash
docker compose up -d --build
```

If migration checks fail, make sure the StudyBuddy sessions app label is used:

```bash
docker compose exec -T web python manage.py makemigrations study_sessions --check --dry-run --settings=config.settings.local
```

Do not use `makemigrations sessions` for the StudyBuddy study workflow. Django's
built-in session framework already uses the `sessions` app label.

If anonymous route redirects look wrong, the current login route is:

```text
/users/login/
```

If coverage upload fails in CI, confirm the Codecov repository is active and
the `CODECOV_TOKEN` secret is configured.

## Final Receipt

Before handing off a change, the expected local receipt is:

```text
Docker/PostgreSQL stack starts.
Django system check passes.
study_sessions migrations are clean.
Black check passes.
Ruff check passes.
Full pytest suite passes.
Dashboard/session focused suite passes.
Sprint 2 Day 5 runbook passes when full workflow verification is required.
```
