# StudyBuddy Architecture

StudyBuddy-Django-App is structured as a modular Django SaaS MVP.

The architecture uses Django templates and Bootstrap for the web interface, Django models for domain persistence, PostgreSQL for the database, and pytest for verification.

## Sprint 1 architecture goals

Sprint 1 establishes the foundation needed for later product work:

- Clear project layout
- Environment-specific settings
- PostgreSQL-backed persistence
- Email-first custom user model
- Role-aware access foundation
- Authenticated dashboard shell
- Tests that verify user and access behaviour

## Project layout

```text
studybuddy-django-app/
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
        users/
        roles/
        dashboard/

    templates/
    static/
    docs/

## Environment boundaries

Settings are split by runtime responsibility:

- `base.py` contains shared Django configuration.
- `local.py` contains Docker-backed development defaults.
- `test.py` contains PostgreSQL-backed test and CI behaviour.
- `production.py` contains deployment-only security and required environment configuration.
