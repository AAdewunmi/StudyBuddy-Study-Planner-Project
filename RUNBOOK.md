# StudyBuddy Runbook

This runbook describes the current operational workflow for
StudyBuddy-Django-App. It reflects the current MVP: authenticated users can
manage study sessions, capture notes, view personal dashboard metrics from
stored data, and generate deterministic AI/NLP insights from their notes.

## Current Status

StudyBuddy is a Docker-backed Django SaaS MVP with:

- email-first custom users and authentication under `/users/`;
- role helpers exposed through `user.studybuddy_roles`;
- role-aware navigation context for product admin and regular user surfaces;
- owner-scoped study sessions and notes under `/sessions/`;
- deterministic owner-scoped insights under `/insights/`;
- data-backed authenticated dashboards under `/dashboard/`, including personal
  study metrics for regular users and operational platform metrics for admins;
- user-scoped selectors in `apps/sessions/selectors.py`;
- aggregate session metrics in `apps/sessions/services.py`;
- aggregate insight metrics in `apps/insights/metrics.py`;
- dashboard context composition in `apps/dashboard/services.py`;
- custom HTTP 400, 403, 404, and 500 templates under `templates/`;
- custom template styling in `static/css/theme.css`;
- PostgreSQL-backed local, test, and production settings modules;
- Render Blueprint deployment in `render.yaml`.

Archived planning notes are preserved in:

```text
docs/studybuddy-canonical-implementation-outline.md
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
make build
make up
make migrate
```

Open the app at:

```text
http://localhost:8000
```

## Day-To-Day Local Workflow

Start or rebuild the local stack:

```bash
make up
```

Check running services:

```bash
docker compose ps
```

Run the Django system check:

```bash
make check
```

Apply migrations:

```bash
make migrate
```

Confirm model migrations are clean:

```bash
make check-migrations
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
make format-check
make lint
make test
```

The Makefile keeps `DJANGO_SETTINGS_MODULE=config.settings.test` and
`TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test`
explicit for Docker-backed test commands.

To auto-fix local formatting and import-order issues:

```bash
make format
docker compose exec -T web python -m ruff check . --fix
```

## Focused Verification

Run the current release verification workflow:

```bash
make release-verify
```

That script verifies:

- Docker/PostgreSQL startup;
- Django system checks and migrations;
- local and production settings checks;
- static collection and Docker image readiness;
- full regression suite and coverage-producing CI path;
- Render runtime contract and `/health/` verification;
- live product smoke checks when a Render URL is available.

Expected current receipts:

```text
Production deployment check passes.
Production static collection succeeds.
Full project test suite passes.
Live Render /health/ returns HTTP 200.
Release verification script reaches its final receipt.
```

Run focused product-area suites for narrower changes:

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests apps/sessions/tests -q
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/insights/tests -q
```

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
- `insights:list` -> `/insights/`
- `insights:generate` -> `/insights/sessions/<session_id>/generate/`
- `health-check` -> `/health/`
- custom production error templates -> `400.html`, `403.html`, `404.html`,
  `500.html`

## Settings Modules

StudyBuddy uses explicit settings modules:

- `config.settings.local`: Docker-backed local development.
- `config.settings.test`: test and CI behavior.
- `config.settings.production`: deployment behavior.

Docker Compose runs with `config.settings.local`. Tests should run with
`config.settings.test`.

Render production deployment is defined in `render.yaml`. The Blueprint creates
the Docker web service, managed PostgreSQL database, `/health/` check, and
pre-deploy migration command. It stores non-secret runtime values in the
Blueprint, prompts for `DJANGO_SECRET_KEY` and email provider values, and
derives `DATABASE_URL` from the managed database.

Production requires at least:

- `DJANGO_SETTINGS_MODULE=config.settings.production`
- `DJANGO_SECRET_KEY`
- `DJANGO_ALLOWED_HOSTS`
- `DATABASE_URL`
- `DJANGO_DEFAULT_FROM_EMAIL`
- `DJANGO_EMAIL_HOST`

Production also supports:

- `DATABASE_SSL_REQUIRE`
- `DJANGO_SECURE_SSL_REDIRECT`
- `DJANGO_SECURE_HSTS_SECONDS`
- `DJANGO_CSRF_TRUSTED_ORIGINS`
- `DJANGO_LOG_LEVEL`
- `DJANGO_EMAIL_BACKEND`
- `DJANGO_EMAIL_PORT`
- `DJANGO_EMAIL_HOST_USER`
- `DJANGO_EMAIL_HOST_PASSWORD`
- `DJANGO_EMAIL_USE_TLS`
- `DJANGO_EMAIL_USE_SSL`
- `DJANGO_EMAIL_TIMEOUT`
- `DJANGO_SERVER_EMAIL`
- `RELEASE_SHA`

## Architecture Rules

Keep these boundaries intact:

- Views should not duplicate ownership-sensitive filtering.
- Use `apps/sessions/selectors.py` for user-scoped session and note queries.
- Use `apps/insights/selectors.py` for user-scoped insight queries.
- Use `apps/sessions/services.py` for session aggregate metrics.
- Use `apps/insights/services.py` for deterministic insight generation.
- Use `apps/insights/metrics.py` for insight dashboard summary metrics.
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
- `metrics.current_streak_days`
- `metrics.monthly_sessions`
- `metrics.monthly_minutes`
- `metrics.subject_counts`
- `recent_activity`
- `dashboard_variant`
- `platform_metrics` for admin dashboards

The insights workflow should render:

- latest session insight on the session detail page;
- owner-scoped insight list at `/insights/`;
- insight count, average confidence, top keywords, and recent insight metrics;
- extractive summary, ranked keywords, confidence score, and explanation;
- useful empty state for users with no insights.

## Documentation Map

- `README.md`: project overview, quick start, verification, routes, structure.
- `docs/architecture.md`: app boundaries and service/query responsibilities.
- `docs/authentication.md`: auth routes, role relation, and access rules.
- `docs/domain-model.md`: users, roles, sessions, notes, selectors, services.
- `docs/design-system.md`: template and CSS design-system contract.
- `docs/local-setup.md`: Docker-backed local setup.
- `Makefile`: repeatable aliases for local setup, checks, tests, and release
  verification.
- `docs/studybuddy-canonical-implementation-outline.md`: archived
  implementation planning outline for StudyBuddy.
- `scripts/release-verify.sh`: neutral wrapper for the release verification
  workflow.

## Troubleshooting

If Docker commands fail, confirm Docker Desktop or the Docker daemon is running:

```bash
docker compose ps
```

If code changes do not appear in the running app, rebuild the web container:

```bash
docker compose up -d --build
```

For full-project migration checks, use:

```bash
docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local
```

If you are intentionally checking only session model changes, make sure the
StudyBuddy sessions app label is used:

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
Release verification workflow passes when full workflow verification is required.
```
