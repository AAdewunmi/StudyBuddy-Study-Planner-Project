#!/usr/bin/env bash
#
# Sprint 1 Day 2 Console-Only Verification Runbook
#
# Purpose:
#   Verify the StudyBuddy database-backed local baseline using the current
#   Docker + PostgreSQL workflow.
#
# Execution instructions:
#   1. Run this file from anywhere inside the repository:
#
#        ./docs/sprint-runbook/sprint-1/sprint-1-day-2.sh
#
#   2. If the file is not executable, run:
#
#        chmod +x docs/sprint-runbook/sprint-1/sprint-1-day-2.sh
#
#   3. Docker Desktop or a compatible Docker daemon must be running.
#
# Expected final receipt:
#   - Django connects to PostgreSQL.
#   - Database settings are environment-driven.
#   - Migrations are clean and applied.
#   - PostgreSQL tables exist.
#   - The test suite passes with isolated test settings.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_ROOT_NAME="StudyBuddy-Study-Planner-Project"

section() {
    printf '\n==> %s\n' "$1"
}

run() {
    printf '\n$ %s\n' "$*"
    "$@"
}

capture() {
    printf '\n$ %s\n' "$*" >&2
    "$@"
}

assert_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" != *"$needle"* ]]; then
        printf 'Expected output to include: %s\n' "$needle" >&2
        printf 'Actual output:\n%s\n' "$haystack" >&2
        exit 1
    fi
}

section "Verify repository root"
run cd "$PROJECT_ROOT"
printf 'Repository root: %s\n' "$PROJECT_ROOT"

if [[ "$(basename "$PROJECT_ROOT")" != "$EXPECTED_ROOT_NAME" ]]; then
    printf 'Expected repository directory to end with: %s\n' "$EXPECTED_ROOT_NAME" >&2
    printf 'Actual repository directory: %s\n' "$(basename "$PROJECT_ROOT")" >&2
    exit 1
fi

section "Verify required database and environment files"
required_files=(
    ".env.example"
    "Dockerfile"
    "docker-compose.yml"
    "config/settings/base.py"
    "config/settings/local.py"
    "config/settings/test.py"
    "docs/local-setup.md"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        printf 'Missing required file: %s\n' "$file" >&2
        exit 1
    fi
    printf 'OK: %s\n' "$file"
done

section "Verify documented database environment variables"
env_example="$(<"$PROJECT_ROOT/.env.example")"
assert_contains "$env_example" "DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local"
assert_contains "$env_example" "POSTGRES_DB=studybuddy_local"
assert_contains "$env_example" "POSTGRES_USER=studybuddy"
assert_contains "$env_example" "POSTGRES_PASSWORD=studybuddy"
assert_contains "$env_example" "POSTGRES_HOST=db"
assert_contains "$env_example" "POSTGRES_PORT=5432"
printf 'Database environment defaults documented.\n'

section "Start Docker/PostgreSQL stack"
run docker compose up -d --build

compose_status="$(capture docker compose ps)"
printf '%s\n' "$compose_status"
assert_contains "$compose_status" "db"
assert_contains "$compose_status" "web"
assert_contains "$compose_status" "healthy"

section "Verify PostgreSQL container health"
pg_ready="$(capture docker compose exec -T db pg_isready -U studybuddy -d studybuddy_local)"
printf '%s\n' "$pg_ready"
assert_contains "$pg_ready" "accepting connections"

current_database="$(capture docker compose exec -T db psql -U studybuddy -d studybuddy_local -tAc "SELECT current_database();")"
printf 'current_database=%s\n' "$current_database"
[[ "$current_database" == "studybuddy_local" ]]

current_user="$(capture docker compose exec -T db psql -U studybuddy -d studybuddy_local -tAc "SELECT current_user;")"
printf 'current_user=%s\n' "$current_user"
[[ "$current_user" == "studybuddy" ]]

section "Verify Django can import database-backed settings"
run docker compose exec -T web python -c "import config.settings.local; print('local settings import OK')"
run docker compose exec -T web python -c "import config.settings.test; print('test settings import OK')"
run docker compose exec -T web python manage.py check --settings=config.settings.local
run docker compose exec -T web python manage.py check --database default --settings=config.settings.local

section "Verify Django database settings point to PostgreSQL"
database_settings="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.conf import settings; db=settings.DATABASES['default']; print(db['ENGINE']); print(db['NAME']); print(db['USER']); print(db['HOST']); print(db['PORT'])"
)"
printf '%s\n' "$database_settings"
assert_contains "$database_settings" "django.db.backends.postgresql"
assert_contains "$database_settings" "studybuddy_local"
assert_contains "$database_settings" "studybuddy"
assert_contains "$database_settings" "db"
assert_contains "$database_settings" "5432"

section "Verify migrations are clean and applied"
makemigrations_output="$(capture docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local)"
printf '%s\n' "$makemigrations_output"
assert_contains "$makemigrations_output" "No changes detected"

migrate_output="$(capture docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local)"
printf '%s\n' "$migrate_output"
assert_contains "$migrate_output" "Operations to perform:"

showmigrations_output="$(capture docker compose exec -T web python manage.py showmigrations --settings=config.settings.local)"
printf '%s\n' "$showmigrations_output"
assert_contains "$showmigrations_output" "admin"
assert_contains "$showmigrations_output" "[X] 0001_initial"
assert_contains "$showmigrations_output" "auth"
assert_contains "$showmigrations_output" "contenttypes"
assert_contains "$showmigrations_output" "roles"
assert_contains "$showmigrations_output" "[X] 0002_initial"
assert_contains "$showmigrations_output" "sessions"
assert_contains "$showmigrations_output" "users"

section "Verify PostgreSQL tables exist"
tables_output="$(capture docker compose exec -T db psql -U studybuddy -d studybuddy_local -tAc "\dt")"
printf '%s\n' "$tables_output"
assert_contains "$tables_output" "auth_group"
assert_contains "$tables_output" "django_admin_log"
assert_contains "$tables_output" "django_content_type"
assert_contains "$tables_output" "django_migrations"
assert_contains "$tables_output" "django_session"
assert_contains "$tables_output" "roles_role"
assert_contains "$tables_output" "users_customuser"

migration_records="$(capture docker compose exec -T db psql -U studybuddy -d studybuddy_local -tAc "SELECT app FROM django_migrations ORDER BY app, name;")"
printf '%s\n' "$migration_records"
assert_contains "$migration_records" "admin"
assert_contains "$migration_records" "auth"
assert_contains "$migration_records" "contenttypes"
assert_contains "$migration_records" "roles"
assert_contains "$migration_records" "sessions"
assert_contains "$migration_records" "users"

section "Verify ORM database access through Django"
connection_vendor="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.db import connection; print(connection.vendor)" \
    | tail -n 1
)"
printf 'connection_vendor=%s\n' "$connection_vendor"
[[ "$connection_vendor" == "postgresql" ]]

user_count="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; print(get_user_model().objects.count())" \
    | tail -n 1
)"
printf 'user_count=%s\n' "$user_count"
[[ "$user_count" =~ ^[0-9]+$ ]]

role_count="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from apps.roles.models import Role; print(Role.objects.count())" \
    | tail -n 1
)"
printf 'role_count=%s\n' "$role_count"
[[ "$role_count" =~ ^[0-9]+$ ]]

section "Verify tests with PostgreSQL-backed test settings"
pytest_output="$(capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q)"
printf '%s\n' "$pytest_output"
assert_contains "$pytest_output" "10 passed"

section "Final Tuesday receipt"
run docker compose exec -T web python manage.py check --database default --settings=config.settings.local
run docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local
run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q

printf '\nDjango connects to PostgreSQL.\n'
printf 'Database settings are environment-driven.\n'
printf 'Migrations are clean and applied.\n'
printf 'PostgreSQL tables exist.\n'
printf 'The test suite passes with isolated test settings.\n'
printf 'Sprint 1 Day 2 verification complete.\n'
