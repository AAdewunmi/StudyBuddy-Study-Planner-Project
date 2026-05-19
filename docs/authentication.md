# Authentication And Access Control

StudyBuddy uses an email-first authentication foundation with protected product
surfaces. Sprint 1 established signup, login, logout, profile, dashboard
routing, and role helpers. Sprint 2 now uses that foundation for owner-scoped
study sessions, notes, and data-backed dashboard metrics. Sprint 3 extends the
same owner-scoped access model to deterministic AI/NLP insights.

## User Model

StudyBuddy uses `apps.users.CustomUser`.

The model extends Django's `AbstractUser`, keeps Django's standard permission
fields, and changes the login identifier to email:

```python
USERNAME_FIELD = "email"
```

Email addresses are unique and required. Usernames still exist for Django
compatibility, but account creation can generate one from the email local part
when the signup form leaves `username` blank.

The active auth setting is:

```python
AUTH_USER_MODEL = "users.CustomUser"
```

## Authentication Routes

User-facing authentication routes live under `/users/`:

- `users:signup` -> `/users/signup/`
- `users:login` -> `/users/login/`
- `users:logout` -> `/users/logout/`
- `users:profile` -> `/users/profile/`

Signup and login redirect authenticated users to the dashboard:

```python
LOGIN_URL = "users:login"
LOGIN_REDIRECT_URL = "dashboard:index"
LOGOUT_REDIRECT_URL = "home"
```

The protected dashboard route is:

- `dashboard:index` -> `/dashboard/`

Study workflow routes live under `/sessions/`.

Insight routes live under `/insights/`:

- `insights:list` -> `/insights/`
- `insights:generate` -> `/insights/sessions/<session_id>/generate/`

## Signup Flow

`apps.users.forms.CustomUserCreationForm` validates email uniqueness, optional
username uniqueness, and password confirmation through Django's user creation
form behavior.

A successful signup:

- creates a valid `CustomUser`;
- authenticates the new user;
- redirects to `dashboard:index`.

Duplicate email addresses are rejected at the form layer before creating a user.

## Login Flow

The login page uses Django's `LoginView` with `users/login.html`.

Users log in with their email address and password because the custom user model
uses email as `USERNAME_FIELD`.

Authenticated users who visit login or signup are redirected to the dashboard.

## Profile Flow

`users:profile` is login-protected and renders `templates/users/profile.html`.

The profile displays the current user's display name, email, username, and
assigned StudyBuddy roles.

## Roles

StudyBuddy roles are modeled by `apps.roles.Role`.

Roles have:

- `slug`;
- `display_name`;
- optional `description`;
- timestamps;
- a many-to-many relation to the custom user model.

The user-side relation is:

```python
user.studybuddy_roles
```

Use this relation in templates, views, factories, tests, and permission helpers.
Do not use `user.roles`; that is not the current related name.

## Permission Helpers

`apps.roles.permissions` provides lightweight role-aware helpers:

- `user_has_role(user, role_slug)`;
- `user_has_any_role(user, role_slugs)`;
- `role_required(role_slug)`.

Anonymous users fail role checks. Superusers pass role checks. Regular users
pass only when `user.studybuddy_roles` contains the requested slug.

## Study Workflow Access

All study workflow views require authentication.

Study sessions are resolved through user-scoped selectors before views render or
mutate data. Users can list, create, view, and update their own sessions. They
receive `404` when attempting to access another user's session detail or update
URL.

Study notes inherit ownership through their parent session. Note create, update,
and delete paths resolve the parent session through the authenticated user before
reading or writing notes.

## Insight Access

All insight views require authentication.

Study insights inherit ownership through their parent session. A user can only
generate insights for sessions they own, and can only view insights attached to
their own sessions.

Insight generation resolves the source `StudySession` with `owner=request.user`
before calling the service layer. Insight list and latest-insight selectors
filter through `session__owner` so another user's generated insight is excluded
at query level.

Anonymous users are redirected to the login page before viewing the insights
dashboard or generating an insight.

## Dashboard Access

The dashboard is a protected, data-backed product surface.

It renders prepared context from `apps.dashboard.services.build_dashboard_context`.
That context includes:

- `metrics.total_sessions`;
- `metrics.completed_sessions`;
- `metrics.total_minutes`;
- `metrics.note_count`;
- `recent_activity`;
- `roles`.

Dashboard metrics are scoped to the logged-in user and exclude records owned by
other users. The dashboard template only renders prepared values; it does not
calculate counts, sums, filters, or ownership rules.

## Validation

The authentication and access-control journey is covered by HTTP-level tests and
database-backed workflow tests. Tests verify:

- signup page render;
- signup user creation;
- duplicate email rejection;
- signup redirect-follow behavior;
- login with email and password;
- login redirect-follow behavior;
- authenticated redirects away from login/signup;
- profile protection;
- authenticated profile rendering;
- logout redirect behavior;
- dashboard access for authenticated users;
- anonymous dashboard redirects;
- owner-scoped session list, detail, and update behavior;
- note create, update, and delete ownership behavior;
- dashboard metrics scoped to the current user;
- owner-only insight generation;
- insight dashboard authentication;
- insight dashboard owner-only visibility;
- cross-user insight exclusion through selectors and views.
