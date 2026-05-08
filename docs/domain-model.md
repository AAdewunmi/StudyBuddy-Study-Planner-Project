# StudyBuddy Domain Model

StudyBuddy is centered on authenticated, user-owned study activity. Sprint 1
establishes the account, role, dashboard, and authentication foundation. Sprint
2 extends that foundation with study sessions and notes.

## Current Foundation

The active user model is `apps.users.CustomUser`, configured through:

```text
AUTH_USER_MODEL = "users.CustomUser"
```

Users sign up and log in with email addresses. Product roles are modeled by
`apps.roles.Role` and are related to users through `Role.users`, exposed on the
user side as `user.studybuddy_roles`.

The authenticated dashboard is the current product surface. It is protected by
Django authentication and reads the current user's roles for display.

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
