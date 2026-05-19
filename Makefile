# StudyBuddy local development and verification commands.

LOCAL_SETTINGS_MODULE ?= config.settings.local
TEST_SETTINGS_MODULE ?= config.settings.test
TEST_DATABASE_URL ?= postgres://studybuddy:studybuddy@db:5432/studybuddy_test

COMPOSE := docker compose
WEB_EXEC := $(COMPOSE) exec -T web
TEST_ENV := env DJANGO_SETTINGS_MODULE=$(TEST_SETTINGS_MODULE) TEST_DATABASE_URL=$(TEST_DATABASE_URL)

.PHONY: build up down restart logs migrate makemigrations check-migrations test test-insights check deploy-check collectstatic shell superuser lint format format-check ci sprint-3-day-5

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) down
	$(COMPOSE) up -d

logs:
	$(COMPOSE) logs -f web

migrate:
	$(WEB_EXEC) python manage.py migrate --noinput --settings=$(LOCAL_SETTINGS_MODULE)

makemigrations:
	$(WEB_EXEC) python manage.py makemigrations --settings=$(LOCAL_SETTINGS_MODULE)

check-migrations:
	$(WEB_EXEC) python manage.py makemigrations --check --dry-run --settings=$(LOCAL_SETTINGS_MODULE)

test:
	$(WEB_EXEC) $(TEST_ENV) pytest -q

test-insights:
	$(WEB_EXEC) $(TEST_ENV) pytest apps/insights -q

check:
	$(WEB_EXEC) python manage.py check --settings=$(LOCAL_SETTINGS_MODULE)

deploy-check:
	$(WEB_EXEC) python manage.py check --deploy --settings=config.settings.production

collectstatic:
	$(WEB_EXEC) python manage.py collectstatic --noinput --settings=config.settings.production

shell:
	$(WEB_EXEC) python manage.py shell --settings=$(LOCAL_SETTINGS_MODULE)

superuser:
	$(WEB_EXEC) python manage.py createsuperuser --settings=$(LOCAL_SETTINGS_MODULE)

lint:
	$(WEB_EXEC) python -m ruff check .

format:
	$(WEB_EXEC) python -m black .

format-check:
	$(WEB_EXEC) python -m black . --check

ci:
	$(WEB_EXEC) python -m black . --check
	$(WEB_EXEC) python -m ruff check .
	$(WEB_EXEC) python manage.py check --settings=$(LOCAL_SETTINGS_MODULE)
	$(WEB_EXEC) python manage.py makemigrations --check --dry-run --settings=$(LOCAL_SETTINGS_MODULE)
	$(WEB_EXEC) python manage.py migrate --noinput --settings=$(LOCAL_SETTINGS_MODULE)
	$(WEB_EXEC) $(TEST_ENV) pytest -q

sprint-3-day-5:
	./docs/sprint-runbook/sprint-3/sprint-3-day-5.sh
