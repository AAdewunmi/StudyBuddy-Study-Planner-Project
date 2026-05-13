# StudyBuddy Architecture

StudyBuddy-Django-App is structured as a modular Django SaaS MVP. The current
project includes the Sprint 1 authentication foundation and the completed
Sprint 2 core study workflow described in
`docs/codex-studybuddy-sprint-2-outline.md`.

The architecture uses Django templates with project-owned CSS in
`static/css/theme.css`, Django models for domain persistence, PostgreSQL for the
database, selectors for ownership-sensitive queries, services for business
logic, and pytest for verification.

## Current Architecture Goals

StudyBuddy keeps a conservative Django shape:

- Clear app boundaries.
- Environment-specific settings.
- PostgreSQL-backed persistence.
- Email-first custom user model.
- Role-aware access foundation.
- Owner-scoped study sessions and notes.
- Data-backed dashboard metrics.
- Business logic kept out of templates.
- Tests that verify user, access, persistence, and reporting behavior.

## Project Layout

```text
StudyBuddy-Study-Planner-Project/
    manage.py
    requirements.txt
    pyproject.toml
    .env.example

    config/
        settings/
            base.py
            local.py
            test.py
            production.py
        urls.py
        wsgi.py
        asgi.py

    apps/
        dashboard/
            services.py
            views.py
            urls.py
            tests/
        roles/
            models.py
            permissions.py
            tests/
        sessions/
            models.py
            forms.py
            selectors.py
            services.py
            views.py
            urls.py
            tests/
        users/
            models.py
            forms.py
            views.py
            urls.py
            tests/

    templates/
    static/css/theme.css
    docs/
```

## Environment Boundaries

Settings are split by runtime responsibility:

- `base.py` contains shared Django configuration.
- `local.py` contains Docker-backed development defaults.
- `test.py` contains PostgreSQL-backed test and CI behavior.
- `production.py` contains deployment-only security and required environment
  configuration.

Docker Compose uses `config.settings.local`. Tests and CI use
`config.settings.test`.

## URL Boundaries

Current user-facing routes are:

- `/` for the public home page.
- `/users/` for signup, login, logout, and profile routes.
- `/dashboard/` for the authenticated personal dashboard.
- `/sessions/` for study session list, create, detail, update, and note routes.

The project does not use Django's default account namespace for authentication
routes.

## Domain Boundaries

The central Sprint 2 domain is:

```text
CustomUser 1 -> * StudySession 1 -> * StudyNote
CustomUser * -> * Role
```

`StudySession` and `StudyNote` live in `apps.sessions`. The installed app uses
`apps.sessions.apps.StudySessionsConfig`, and its model app label is
`study_sessions` to avoid colliding with Django's built-in
`django.contrib.sessions` app.

## Query And Service Boundaries

StudyBuddy keeps ownership and aggregate logic out of templates:

- `apps/sessions/selectors.py` owns user-scoped session and note queries.
- `apps/sessions/services.py` calculates session-level aggregate metrics.
- `apps/dashboard/services.py` composes dashboard context for views.
- `apps/dashboard/views.py` passes prepared context into the template.
- `templates/dashboard/index.html` only renders prepared values and links.

Dashboard aggregates include:

- total session count;
- completed session count;
- total study minutes;
- note count;
- recent user-owned sessions.

Templates must not calculate counts, sums, filters, or ownership rules.

## UI Boundary

Templates extend `templates/base.html` and use shared classes from
`static/css/theme.css`.

The active design system is custom to StudyBuddy. Templates should not depend on
Bootstrap visual utility classes for layout, cards, buttons, alerts, or metrics.

## Verification Boundary

The current Sprint 2 dashboard and sessions verification command is:

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests apps/sessions/tests -q
```

Expected current receipt:

```text
64 passed
```

The full Docker-backed Sprint 2 verification runbook is:

```bash
./docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
```
