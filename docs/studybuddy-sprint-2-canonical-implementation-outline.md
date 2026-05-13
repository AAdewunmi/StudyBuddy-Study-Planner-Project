# studybuddy-sprint-2-canonical-implementation-outline

Selected sprint: Sprint 2 - Core StudyBuddy workflow.

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

Expected current receipt:

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

Expected current receipt:

```text
64 passed
```

Full Docker-backed runbook:

```bash
./docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
```
