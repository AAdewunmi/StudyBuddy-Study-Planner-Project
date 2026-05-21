# StudyBuddy Canonical Implementation Outline

This is the central canonical implementation file for StudyBuddy. It is the
one place to record the project's implemented product shape, app boundaries,
MVP scope, sprint checkpoints, verification commands, and architectural
decisions that future work should preserve.

Use this document as the implementation source of truth before changing models,
views, selectors, services, templates, URLs, tests, or user-facing product
behaviour. Supporting documents can go deeper on specific areas, but they
should point back here rather than becoming competing canonical sources.

## Canonical Project Baseline

StudyBuddy is a production-minded Django SaaS MVP for study productivity.

The current implementation includes:

- email-first authentication and profile flows under `/users/`
- role-aware access foundations through `apps.roles`
- owner-scoped study sessions and notes under `/sessions/`
- a data-backed authenticated dashboard under `/dashboard/`
- deterministic AI/NLP study insights under `/insights/`
- PostgreSQL-backed local, test, and production settings
- Render Blueprint deployment through `render.yaml`
- project-owned template styling in `static/css/theme.css`
- selectors for ownership-sensitive reads
- services for business logic and template-ready context
- pytest and factory_boy coverage for persistence, access, workflows, and NLP

Canonical implementation boundaries:

- users can only access their own sessions, notes, dashboard data, and insights
- business logic belongs in services/selectors, not templates
- templates use the project design system, not Bootstrap visual classes
- deterministic insight generation does not use an LLM, external AI API, or
  background worker
- confidence scores are quality signals, not probabilities or factual
  correctness claims

Canonical supporting documents:

- `README.md` for project overview, setup, routes, and top-level verification
- `docs/architecture.md` for app boundaries and architectural conventions
- `docs/domain-model.md` for domain entities and relationships
- `docs/design-system.md` for UI and template styling rules
- `docs/ai-nlp-contract.md` for deterministic insight behaviour and MVP scope
- `docs/deployment.md` for Render, Docker, health check, and production
  runtime configuration
- `RUNBOOK.md` for operational commands and handoff checks
- `Makefile` for repeatable local, review, and CI-style command aliases

## Current Verification Baseline

Run the targeted Sprint 3 insight verification:

```bash
make test-insights
```

Run the full Docker-backed test suite:

```bash
make test
```

Run Django configuration checks:

```bash
make check
make check-migrations
```

## Sprint 3: Deterministic AI/NLP Study Insights

Sprint 3 adds deterministic study insights generated from notes attached to a
single user-owned study session.

Business objective: help users review their own study material with an
explainable, testable summary, keyword list, confidence score, and explanation.

Engineering objective: add persisted `StudyInsight` records, deterministic NLP
helpers, owner-scoped generation and retrieval, and dashboard/session-detail UI.

Key deliverables:

- `apps/insights/models.py`
- `apps/insights/services.py`
- `apps/insights/selectors.py`
- `apps/insights/views.py`
- `apps/insights/urls.py`
- `apps/insights/nlp/text_processing.py`
- `apps/insights/nlp/keyword_extraction.py`
- `apps/insights/nlp/summarisation.py`
- `apps/insights/nlp/confidence.py`
- `apps/insights/nlp/explanations.py`
- `templates/insights/insight_list.html`
- `templates/sessions/session_detail.html`
- `docs/ai-nlp-contract.md`

Implementation notes:

- `StudyInsight` stores `session`, `summary`, `keywords`, `confidence`,
  `explanation`, `source_hash`, `created_at`, and `updated_at`.
- Insight ownership is inherited through `StudyInsight.session.owner`.
- The uniqueness contract is one insight per `session` and `source_hash`.
- Source hashes are SHA-256 digests of normalised note text.
- Keyword ranking is deterministic term frequency with alphabetical
  tie-breaking.
- Summaries are extractive and use sentences from the user's notes.
- Re-generating an insight for unchanged notes reuses the existing row.
- Cross-user access is blocked through session-owner filtering.

Verification:

```bash
pytest apps/insights -q
```

Sprint 2 historical receipt:

```text
69 passed
```

## Sprint 2: Core StudyBuddy Workflow

Sprint 2 turns StudyBuddy from an authenticated shell into a usable study
workflow. The sprint introduces study sessions, owner-scoped CRUD behavior,
notes per session, and dashboard metrics that reflect real stored data. The
implementation keeps business logic out of templates by using selectors and
services, with pytest and factory_boy coverage for persistence, validation,
permissions, note maintenance, and dashboard reporting.

Sprint 1 has already created the Django project, custom user model,
authentication flow, dashboard app, role foundation, PostgreSQL local settings,
strict custom template design system, and pytest/factory_boy setup.

Current implementation baseline:

- Authentication routes live under `/users/`.
- The authenticated dashboard route is `/dashboard/`.
- Study workflow routes live under `/sessions/`.
- The StudyBuddy sessions app uses the `study_sessions` model app label.
- Templates use project-owned classes from `static/css/theme.css`.

## Monday: Study Session Domain Model

SDLC focus: core domain modeling, persistence, validation.

Business objective: introduce the core business entity that lets users record
actual study activity.

Engineering objective: create the `StudySession` model with ownership,
validation, admin registration, factories, and persistence tests.

Concepts introduced:

- Domain entities.
- Ownership rules.
- Model validation.
- Database-backed tests.
- Study workflow lifecycle states.

Key deliverables:

- `apps/sessions/__init__.py`
- `apps/sessions/apps.py`
- `apps/sessions/models.py`
- `apps/sessions/admin.py`
- `apps/sessions/factories.py`
- `apps/sessions/tests/__init__.py`
- `apps/sessions/tests/test_models.py`
- `config/settings/base.py`
- `docs/domain-model.md`

Implementation notes:

- The installed app is `apps.sessions.apps.StudySessionsConfig`.
- The model app label is `study_sessions` to avoid colliding with Django's
  built-in `django.contrib.sessions`.
- Migration commands should target `study_sessions`.

Verification:

```bash
python manage.py makemigrations study_sessions --settings=config.settings.local
python manage.py migrate --settings=config.settings.local
pytest apps/sessions/tests/test_models.py -q
```

## Tuesday: Session List And Create Flow

SDLC focus: user workflow implementation, authenticated CRUD behavior.

Business objective: let users create sessions and view their own study history.

Engineering objective: build session list and create routes, forms, templates,
navigation, and tests.

Concepts introduced:

- Create workflow.
- List workflow.
- Authenticated product routes.
- Ownership filtering.
- Empty-state UX.

Key deliverables:

- `apps/sessions/forms.py`
- `apps/sessions/views.py`
- `apps/sessions/urls.py`
- `apps/sessions/tests/test_session_views.py`
- `templates/sessions/session_list.html`
- `templates/sessions/session_form.html`
- `templates/base.html`
- `config/urls.py`

Implementation notes:

- Session list data is scoped before it reaches the template.
- Templates use project-owned classes from `static/css/theme.css`, such as
  `container-ui`, `page-stack`, `card-ui`, `btn-ui`, and `quote-card`.
- The session creation route is `sessions:create` at `/sessions/new/`.

Verification:

```bash
pytest apps/sessions/tests/test_session_views.py -q
```

Manual checks:

- Anonymous users are redirected from `/sessions/`.
- Authenticated users can load `/sessions/`.
- `POST /sessions/new/` creates a session owned by the logged-in user.

## Wednesday: Session Detail, Update, And Ownership Enforcement

SDLC focus: permission validation, workflow completion, edge-case testing.

Business objective: allow users to manage their own sessions while preventing
access to another user's data.

Engineering objective: implement detail and update views with strict owner
scoping and permission tests.

Concepts introduced:

- Object-level access control.
- Update workflow.
- 404 ownership protection.
- Permission testing.
- Query-level scoping.

Key deliverables:

- `apps/sessions/views.py`
- `apps/sessions/urls.py`
- `apps/sessions/tests/test_session_permissions.py`
- `apps/sessions/tests/test_session_update.py`
- `templates/sessions/session_detail.html`
- `templates/sessions/session_form.html`

Implementation notes:

- Detail and update views resolve sessions through user-scoped selectors.
- Users receive `404` for another user's session detail or update URL.
- The same validated `StudySessionForm` supports create and update flows.

Verification:

```bash
pytest apps/sessions/tests -q
```

Manual checks:

- A user can open `/sessions/<own-session-id>/`.
- A user receives `404` for `/sessions/<other-user-session-id>/`.
- A user can edit their own session through
  `/sessions/<own-session-id>/edit/`.

## Thursday: Study Notes Per Session

SDLC focus: relational modeling, workflow enrichment, persistence testing.

Business objective: give users a place to capture actual study content, not
only schedule metadata.

Engineering objective: add `StudyNote`, tie it to sessions, support note
create/update/delete workflows, and show notes on session detail.

Concepts introduced:

- Parent-child domain relationships.
- Note capture workflows.
- Inline form handling.
- Relational ownership checks.
- Content validation.

Key deliverables:

- `apps/sessions/models.py`
- `apps/sessions/forms.py`
- `apps/sessions/views.py`
- `apps/sessions/admin.py`
- `apps/sessions/factories.py`
- `apps/sessions/tests/test_notes.py`
- `apps/sessions/tests/test_session_notes.py`
- `templates/sessions/session_detail.html`

Implementation notes:

- Notes inherit ownership through their parent session.
- Note create, update, and delete routes all resolve ownership through the
  session relationship.
- Short note content is rejected.
- Users cannot create, update, or delete notes through another user's session.

Verification:

```bash
python manage.py makemigrations study_sessions --settings=config.settings.local
python manage.py migrate --settings=config.settings.local
pytest apps/sessions/tests/test_notes.py apps/sessions/tests/test_session_notes.py -q
```

Manual checks:

- A logged-in user can add a note from their own session detail page.
- The new note appears immediately under that session.
- A user can update and delete their own notes.
- Posting to another user's session returns `404`.

## Friday: Dashboard Metrics With Selectors And Services

SDLC focus: business logic separation, reporting, workflow validation.

Business objective: show users immediate value by reflecting their study
behavior back through personal metrics.

Engineering objective: add selectors and services for dashboard metrics and
render those values in the dashboard.

Concepts introduced:

- Selector pattern.
- Service layer.
- Aggregate metrics.
- Dashboard reporting.
- User-scoped calculations.
- Template aggregate boundaries.

Key deliverables:

- `apps/sessions/selectors.py`
- `apps/sessions/services.py`
- `apps/sessions/tests/test_selectors.py`
- `apps/sessions/tests/test_services.py`
- `apps/dashboard/services.py`
- `apps/dashboard/views.py`
- `apps/dashboard/tests/test_dashboard_metrics.py`
- `apps/dashboard/tests/test_services.py`
- `apps/dashboard/tests/test_dashboard_views.py`
- `templates/dashboard/index.html`
- `templates/base.html`
- `static/css/theme.css`
- `docs/design-system.md`
- `docs/sprint-runbook/sprint-2/sprint-2-day-5.sh`

Implementation notes:

- Selectors keep ownership-sensitive query logic in one place.
- Session services calculate total sessions, completed sessions, total minutes,
  note count, and recent sessions.
- Dashboard services build template-ready context.
- Dashboard views pass prepared context into templates.
- Dashboard templates render `metrics.*` and `recent_activity`; they do not
  calculate aggregates.
- Bootstrap message alerts were replaced with project-owned `message-ui`
  classes for strict design-system purity.

Verification:

```bash
pytest apps/dashboard/tests apps/sessions/tests -q
```

Sprint 2 historical receipt:

```text
64 passed
```

Manual checks:

- A new user sees an empty dashboard with useful calls to action.
- A user with sessions sees total sessions, completed sessions, study minutes,
  notes, and recent activity.
- Metrics exclude records belonging to other users.
- `sessions:create` and `sessions:detail` links resolve to real routes.

## Sprint 2 Completion Checkpoint

Sprint 2 is complete when all of the following are true:

- `StudySession` exists and belongs to a user.
- Invalid session durations are rejected.
- Completed sessions cannot be dated in the future.
- Authenticated users can list their own sessions.
- Authenticated users can create sessions.
- Authenticated users can view their own session detail pages.
- Authenticated users can update their own sessions.
- Users receive `404` for another user's session detail or update URL.
- `StudyNote` exists and belongs to a session.
- Users can add notes to their own sessions.
- Users can update and delete their own notes.
- Users cannot create, update, or delete notes through another user's session.
- Dashboard metrics reflect stored sessions and notes.
- Dashboard metrics are scoped to the logged-in user.
- Empty dashboard state remains useful for new users.
- Templates follow the project design system in `docs/design-system.md`,
  `templates/base.html`, and `static/css/theme.css`.
- The Sprint 2 dashboard and sessions test suites pass.

Final Sprint 2 verification command:

```bash
pytest apps/dashboard/tests apps/sessions/tests -q
```

Sprint 2 historical receipt:

```text
64 passed
```

Full Docker-backed runbook:

```bash
./docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
```
