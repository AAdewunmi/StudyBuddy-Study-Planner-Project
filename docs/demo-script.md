# StudyBuddy MVP Demo Script

This script provides a repeatable walkthrough for demonstrating the StudyBuddy
SaaS MVP to reviewers.

## Demo Goal

Show that StudyBuddy is a working SaaS-style study productivity application
with authentication, user-owned data, study sessions, notes, dashboard metrics,
deterministic AI/NLP insights, Docker-backed verification, CI, and a Render
deployment contract.

## Demo Setup

Use the live Render URL after it has been created and verified:

```text
https://studybuddy-django-app.onrender.com
```

If Render generated a different hostname, use that URL instead and keep
`render.yaml`, `.env.example`, `README.md`, and `docs/deployment.md` aligned.

For a local demo, start the Docker-backed stack from the repository root:

```bash
cp .env.example .env
make build
make up
make migrate
```

Then open:

```text
http://localhost:8000
```

## Pre-Demo Checks

Confirm the local product and verification path are healthy:

```bash
make ci
```

Confirm the production settings contract can load locally with Render-like
environment variables:

```bash
docker compose exec -T web env \
  DJANGO_SECRET_KEY='local-deploy-check-only-long-random-looking-secret-1234567890' \
  DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1 \
  DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:8000,http://127.0.0.1:8000 \
  DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local \
  DATABASE_SSL_REQUIRE=False \
  DJANGO_DEFAULT_FROM_EMAIL=local-deploy-check@example.com \
  DJANGO_EMAIL_HOST=localhost \
  python manage.py check --deploy --settings=config.settings.production
```

Expected receipt:

```text
System check identified no issues (0 silenced).
```

For the full release verification checklist, run:

```bash
./docs/sprint-runbook/sprint-4/sprint-4-day-4.sh
```

If the live Render hostname is different:

```bash
LIVE_URL="https://your-render-service.onrender.com" \
  ./docs/sprint-runbook/sprint-4/sprint-4-day-4.sh
```

## Product Walkthrough

1. Open the app home page.
2. Go to `/users/signup/`.
3. Sign up with a reviewer-safe test email address.
4. Confirm signup redirects to `/dashboard/`.
5. Open `/sessions/`.
6. Create a new study session.
7. Open the session detail page.
8. Add a note to the session.
9. Generate an insight from the session notes.
10. Confirm the insight appears on the session detail page.
11. Open `/insights/` and confirm the generated insight appears there.
12. Return to `/dashboard/` and confirm metrics and recent activity reflect the
    session, note, and insight.
13. Open `/users/profile/` and confirm the signed-in user's email is shown.
14. Log out from `/users/logout/`.
15. Visit `/dashboard/` while logged out and confirm it redirects to login.

## Talking Points

- Authentication is email-first and routes through the canonical `/users/`
  namespace.
- Study sessions, notes, dashboard data, and insights are scoped to the
  authenticated owner.
- AI/NLP insight generation is deterministic: unchanged notes reuse the same
  generated insight instead of creating duplicates.
- `/health/` verifies service and database reachability for deployment checks.
- Static assets are collected into the Docker image and served through
  WhiteNoise manifest storage in production.
- `render.yaml` defines the Render web service, managed PostgreSQL database,
  health check path, Docker runtime, pre-deploy migrations, and non-secret
  runtime variables.
- Render injects `DJANGO_SECRET_KEY`, provides `DATABASE_URL` from managed
  PostgreSQL, injects email provider settings, and exposes `RENDER_GIT_COMMIT`
  for release traceability.

## Live Render Acceptance

The live deployment is demo-ready only when these checks pass against the live
Render URL:

```bash
curl -fsS https://studybuddy-django-app.onrender.com/health/
curl -fsS https://studybuddy-django-app.onrender.com/ >/tmp/studybuddy-home.html
```

The health response should include:

```json
{
  "status": "ok",
  "service": "studybuddy",
  "release": "<deployed commit SHA>",
  "checks": {
    "database": "ok"
  }
}
```

If Render returns `404` with `x-render-routing: no-server`, the app code and
docs can still be locally verified, but the live service URL has not been
created, deployed, or routed correctly yet.

## Demo Result

The demo is complete when the reviewer has seen signup, login, dashboard,
session creation, note creation, deterministic insight generation, logout,
protected-route redirect behaviour, local verification, and the Render
deployment contract.
