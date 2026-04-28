# StudyBuddy-Django-App

![CI Pipeline](https://img.shields.io/badge/CI-pending-lightgrey)
![Python](https://img.shields.io/badge/Python-3.11%2B-blue)
![Django](https://img.shields.io/badge/Django-5.x-green)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-required-blue)
![Tests](https://img.shields.io/badge/tests-pytest-blue)
![Code Style](https://img.shields.io/badge/code%20style-ruff%20%2B%20black-black)
![Docker](https://img.shields.io/badge/Docker-planned%20Sprint%204-lightgrey)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

StudyBuddy-Django-App is a production-minded SaaS MVP for study productivity.

The product helps users register, manage study sessions, capture notes, review personal progress, and generate lightweight deterministic AI/NLP insights from their own study material.

Sprint 1 establishes the product foundation, Django architecture, PostgreSQL configuration, custom user model, roles foundation, authentication workflow, protected dashboard shell, and first test suite.

## Sprint 1 scope

Sprint 1 delivers:

- Django project structure under `config/`
- Split settings for base, local, and production
- Environment-driven configuration
- PostgreSQL local persistence configuration
- Email-first custom user model
- Role model and user-role relationship
- Signup, login, logout, and profile views
- Bootstrap-backed template shell
- Protected dashboard
- Pytest, pytest-django, and factory_boy test baseline
- Practical architecture and setup documentation

Sprint 1 does not yet implement study sessions, notes, dashboard metrics, AI/NLP insights, Docker, CI, or deployment. Those are delivered in later sprints.

## Tech stack

- Python 3.11+
- Django 5.x
- PostgreSQL
- pytest
- pytest-django
- factory_boy
- Bootstrap 5
- django-environ

## Local setup

Create and activate a virtual environment.

```bash
python -m venv .venv
source .venv/bin/activate
