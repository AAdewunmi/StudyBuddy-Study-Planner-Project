# Authentication and Access Control

Sprint 1 establishes the StudyBuddy identity baseline and the first protected
product surface.

The current goal is a real SaaS-shaped authentication journey without
overbuilding permissions before study-session workflows exist.

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

User-facing authentication routes live under `/accounts/`:

- `users:signup` -> `/accounts/signup/`
- `users:login` -> `/accounts/login/`
- `users:logout` -> `/accounts/logout/`
- `users:profile` -> `/accounts/profile/`

Signup and login redirect authenticated users to the dashboard:

```python
LOGIN_URL = "users:login"
LOGIN_REDIRECT_URL = "dashboard:index"
LOGOUT_REDIRECT_URL = "home"
```

The protected dashboard route is:

- `dashboard:index` -> `/dashboard/`

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

## Dashboard Access

The dashboard is the Sprint 1 post-login product destination.

It is intentionally a protected shell until Sprint 2 adds study-session data.
It displays placeholder study metrics, an empty-session state, account access,
and role-aware messaging backed by `user.studybuddy_roles`.

## Validation

The authentication journey is covered by HTTP-level tests, not just isolated
model creation. Tests verify:

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
- dashboard access for authenticated users.
