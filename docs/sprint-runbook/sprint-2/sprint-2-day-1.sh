#!/usr/bin/env bash
#
# Sprint 2 Day 1 Study Session Model Verification Runbook
#
# Purpose:
#   Verify that the StudyBuddy Sprint 2 Day 1 study session foundation is
#   aligned with the current Django project. This checks the installed sessions
#   app, StudySession and StudyNote model registration, clean migrations,
#   model validation rules, and the Sprint 2 model test suite.
#
# Execution instructions:
#   1. Run this file from anywhere inside the repository:
#
#        ./docs/sprint-runbook/sprint-2/sprint-2-day-1.sh
#
#   2. If the file is not executable, run:
#
#        chmod +x docs/sprint-runbook/sprint-2/sprint-2-day-1.sh
#
#   3. Docker Desktop or a compatible Docker daemon must be running.
#   4. The script builds/recreates the Docker Compose web container so checks
#      run against the same source and dependency environment as the app.
#
# Expected final receipt:
#   - Repository root verified.
#   - Sprint 2 Day 1 files exist.
#   - apps.sessions is installed with the study_sessions app label.
#   - StudySession and StudyNote are registered with Django.
#   - Django system checks pass.
#   - study_sessions migrations are clean and applied.
#   - StudySession fields and validation rules are verified.
#   - apps/sessions/tests/test_models.py passes with 8 tests.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_TEST_COUNT=8

section() {
    printf '\n==> %s\n' "$1"
}

run() {
    printf '\n$ %s\n' "$*"
    "$@"
}

section "Verify repository root"
run cd "$PROJECT_ROOT"

if [[ ! -f "$PROJECT_ROOT/manage.py" ]]; then
    printf 'ERROR: manage.py not found. Expected repository root: %s\n' "$PROJECT_ROOT" >&2
    exit 1
fi

printf 'Repository root: %s\n' "$PROJECT_ROOT"

section "Confirm Sprint 2 Day 1 files exist"
required_files=(
    "apps/sessions/__init__.py"
    "apps/sessions/apps.py"
    "apps/sessions/models.py"
    "apps/sessions/admin.py"
    "apps/sessions/factories.py"
    "apps/sessions/migrations/0001_initial.py"
    "apps/sessions/tests/__init__.py"
    "apps/sessions/tests/test_models.py"
    "docs/domain-model.md"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        printf 'ERROR: Missing required file: %s\n' "$file" >&2
        exit 1
    fi

    printf 'FOUND: %s\n' "$file"
done

section "Build and start Docker/PostgreSQL stack"
run docker compose up -d --build
run docker compose ps

section "Confirm sessions app is installed"
run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.apps import apps

assert apps.is_installed("apps.sessions")
assert apps.get_app_config("study_sessions").name == "apps.sessions"
assert apps.get_model("study_sessions", "StudySession")
assert apps.get_model("study_sessions", "StudyNote")

print("sessions app installed")
print("study_sessions app label verified")
print("StudySession model registered")
print("StudyNote model registered")
PY

section "Run Django system check"
run docker compose exec -T web python manage.py check --settings=config.settings.local

section "Confirm sessions migrations are clean"
run docker compose exec -T web python manage.py makemigrations study_sessions --check --dry-run --settings=config.settings.local

section "Apply database migrations"
run docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local

section "Verify StudySession model fields"
run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from apps.sessions.models import StudySession

field_names = {field.name for field in StudySession._meta.fields}

expected_fields = {
    "id",
    "owner",
    "title",
    "subject",
    "status",
    "study_date",
    "duration_minutes",
    "created_at",
    "updated_at",
}

missing_fields = expected_fields - field_names

assert not missing_fields, f"Missing StudySession fields: {sorted(missing_fields)}"

print("StudySession fields verified")
print("Expected fields:", ", ".join(sorted(expected_fields)))
PY

section "Verify StudySession validation rules"
run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.utils import timezone

from apps.sessions.models import StudySession

User = get_user_model()

user, _ = User.objects.get_or_create(
    email="sprint2.day1.verify@example.com",
    defaults={"username": "sprint2-day1-verify"},
)
user.set_password("temporary-test-password")
user.save()

valid_session = StudySession(
    owner=user,
    title="Sprint 2 Day 1 verification session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)
valid_session.full_clean()
valid_session.save()

invalid_duration = StudySession(
    owner=user,
    title="Invalid duration",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=0,
)

try:
    invalid_duration.full_clean()
except ValidationError:
    print("Invalid duration rejected")
else:
    raise AssertionError("Invalid duration was accepted")

future_completed = StudySession(
    owner=user,
    title="Future completed session",
    subject="Django",
    status=StudySession.Status.COMPLETED,
    study_date=timezone.localdate() + timedelta(days=1),
    duration_minutes=30,
)

try:
    future_completed.full_clean()
except ValidationError:
    print("Future completed session rejected")
else:
    raise AssertionError("Future completed session was accepted")

print("Valid StudySession saved")
print("StudySession validation rules verified")
PY

section "Run Sprint 2 Day 1 model tests"
run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions/tests/test_models.py -q

section "Final receipt"
printf 'Repository root verified.\n'
printf 'Sprint 2 Day 1 files verified.\n'
printf 'apps.sessions installed with study_sessions app label.\n'
printf 'StudySession and StudyNote model registration verified.\n'
printf 'Django system check passed.\n'
printf 'study_sessions migrations are clean and applied.\n'
printf 'StudySession fields and validation rules verified.\n'
printf 'apps/sessions/tests/test_models.py passes with %s tests.\n' "$EXPECTED_TEST_COUNT"
printf 'Sprint 2 Day 1 verification complete.\n'
