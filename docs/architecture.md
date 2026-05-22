# StudyBuddy Architecture

StudyBuddy-Django-App is structured as a modular Django SaaS MVP. The current
project includes the authentication foundation, core study workflow,
deterministic AI/NLP insight workflow, and deployment verification path. Current
release proof lives in `docs/final-verification.md`; archived implementation
planning remains in `docs/studybuddy-canonical-implementation-outline.md`.

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
- Data-backed personal and admin dashboard metrics.
- Deterministic owner-scoped study insights.
- Custom production error pages.
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
            context_processors.py
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
        insights/
            metrics.py
            models.py
            selectors.py
            services.py
            views.py
            urls.py
            nlp/
            tests/
        users/
            models.py
            forms.py
            views.py
            urls.py
            tests/

    templates/
        400.html
        403.html
        404.html
        500.html
    static/css/theme.css
    scripts/
        release-verify.sh
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
`config.settings.test`. Render production infrastructure is defined in
`render.yaml`, which creates the Docker web service, managed PostgreSQL
database, health check, migration command, and non-secret production
environment variables.

## URL Boundaries

Current user-facing routes are:

- `/` for the public home page.
- `/users/` for signup, login, logout, and profile routes.
- `/dashboard/` for authenticated personal and product-admin dashboards.
- `/sessions/` for study session list, create, detail, update, and note routes.
- `/insights/` for the authenticated insights dashboard.
- `/insights/sessions/<session_id>/generate/` for owner-only insight
  generation.

The project does not use Django's default account namespace for authentication
routes.

## Domain Boundaries

The current domain shape is:

```text
CustomUser 1 -> * StudySession 1 -> * StudyNote
StudySession 1 -> * StudyInsight
CustomUser * -> * Role
```

`StudySession` and `StudyNote` live in `apps.sessions`. The installed app uses
`apps.sessions.apps.StudySessionsConfig`, and its model app label is
`study_sessions` to avoid colliding with Django's built-in
`django.contrib.sessions` app.

`StudyInsight` lives in `apps.insights`. Insights are generated from notes on a
single study session, inherit ownership through `StudyInsight.session.owner`,
and are unique per `session` and `source_hash`.

## Query And Service Boundaries

StudyBuddy keeps ownership and aggregate logic out of templates:

- `apps/sessions/selectors.py` owns user-scoped session and note queries.
- `apps/sessions/services.py` calculates session-level aggregate metrics.
- `apps/insights/metrics.py` calculates insight dashboard summary metrics.
- `apps/dashboard/services.py` composes personal and admin dashboard context
  for views.
- `apps/roles/context_processors.py` exposes role flags for shared navigation.
- `apps/dashboard/views.py` passes prepared context into the template.
- `templates/dashboard/index.html` only renders prepared values and links.
- `apps/insights/selectors.py` owns user-scoped insight queries.
- `apps/insights/services.py` owns deterministic insight generation and reuse.
- `apps/insights/nlp/` contains deterministic text processing, keyword
  extraction, summarisation, confidence scoring, and explanation helpers.
- `apps/insights/views.py` keeps NLP internals out of views by calling the
  service layer.

Dashboard aggregates include:

- total session count;
- completed session count;
- total study minutes;
- note count;
- recent user-owned sessions;
- study streaks, monthly totals, subject counts, and note coverage;
- admin platform totals for users, roles, sessions, notes, insights, and
  deployment visibility.

Templates must not calculate counts, sums, filters, or ownership rules.

Insight views must filter through `session__owner` or resolve the source session
through the authenticated user before creating or returning an insight.

## UI Boundary

Templates extend `templates/base.html` and use shared classes from
`static/css/theme.css`.

The active design system is custom to StudyBuddy. Templates should not depend on
Bootstrap visual utility classes for layout, cards, buttons, alerts, or metrics.
Custom error templates live at `templates/400.html`, `templates/403.html`,
`templates/404.html`, and `templates/500.html`.

## Verification Boundary

The current release verification command is:

```bash
make release-verify
```

Expected current receipt:

```text
Render deployment and release verification complete.
Full project test suite passes.
```

Run the dashboard and sessions focused suite when changing study workflow code:

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests apps/sessions/tests -q
```
