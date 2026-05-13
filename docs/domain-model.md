# StudyBuddy Domain Model

StudyBuddy is centered on authenticated, user-owned study activity. Sprint 1
established the account, role, dashboard, and authentication foundation. Sprint
2 extends that foundation with study sessions, notes, selectors, services, and
dashboard metrics.

## Current Foundation

The active user model is `apps.users.CustomUser`, configured through:

```text
AUTH_USER_MODEL = "users.CustomUser"
```

Users sign up and log in with email addresses. Product roles are modeled by
`apps.roles.Role` and are related to users through `Role.users`, exposed on the
user side as `user.studybuddy_roles`.

The authenticated dashboard is a data-backed product surface. It is protected by
Django authentication, reads the current user's roles for display, and renders
study metrics prepared by Python services.

## Study Session Ownership

Every study session belongs to one authenticated user. User-owned data must be
filtered at query level before it reaches views, templates, or forms.

The core selector pattern is:

```python
StudySession.objects.filter(owner=request.user)
```

This keeps one user's study data isolated from every other user, even if views
or templates change later.

## StudySession

`apps.sessions.models.StudySession` represents one planned or completed block of
study activity.

Core fields:

- `owner`: foreign key to `settings.AUTH_USER_MODEL`
- `title`: short user-facing session title
- `subject`: subject or topic being studied
- `status`: one of `planned`, `in_progress`, or `completed`
- `study_date`: date the session is planned for or took place
- `duration_minutes`: duration from 1 minute to 24 hours
- `created_at` and `updated_at`: audit timestamps

Domain rules:

- Sessions are ordered newest first by `study_date`, then creation time.
- Completed sessions cannot be dated in the future.
- `duration_minutes` must stay between 1 and 1440 minutes.
- `note_count` reports attached notes and returns `0` before the session exists
  in the database.

## StudyNote

`apps.sessions.models.StudyNote` represents a note attached to a
`StudySession`.

Core fields:

- `session`: foreign key to `StudySession`
- `content`: note body
- `created_at`: creation timestamp

Domain rules:

- Notes inherit ownership through their parent session.
- Views should resolve the parent session through `request.user` before reading
  or writing notes.
- Notes are ordered newest first.
- Notes must contain at least 10 non-whitespace characters.
- `word_count` reports the number of whitespace-separated words.
- Note create, update, and delete workflows are all scoped through the parent
  session owner.

## Selectors And Services

Ownership-sensitive query logic lives in `apps/sessions/selectors.py`.

Current selectors include:

- `get_sessions_for_user(user)`;
- `get_session_for_user_or_404(user, pk)`;
- `get_recent_sessions_for_user(user, limit=5)`;
- `get_notes_for_session(session)`;
- `get_notes_for_user(user)`;
- `get_note_for_user_or_404(user, session_pk, note_pk)`.

Aggregate session business logic lives in `apps/sessions/services.py`.

`build_session_metrics_for_user(user)` returns a `SessionMetrics` value with:

- `total_sessions`;
- `completed_sessions`;
- `total_minutes`;
- `note_count`;
- `recent_sessions`.

Dashboard context composition lives in `apps/dashboard/services.py`.

`build_dashboard_context(user)` returns:

- `metrics`;
- `recent_activity`;
- `roles`.

Templates render these prepared values. Templates must not calculate aggregate
counts, sums, filters, recent-session query logic, or ownership rules.

## App Label

The project already uses Django's built-in `django.contrib.sessions` app for
browser session storage. The StudyBuddy study workflow therefore uses the
explicit model app label `study_sessions` to avoid colliding with Django's
built-in `sessions` label if the app is installed in a later sprint.

## Relationship Summary

```text
CustomUser 1 -> * StudySession 1 -> * StudyNote
CustomUser * -> * Role
```

`CustomUser` owns study sessions. `StudySession` owns notes. `Role` supports
role-aware behavior independently of the study session workflow.

## Sprint 2 Outline

The canonical Sprint 2 implementation outline is
`docs/codex-studybuddy-sprint-2-outline.md`.
