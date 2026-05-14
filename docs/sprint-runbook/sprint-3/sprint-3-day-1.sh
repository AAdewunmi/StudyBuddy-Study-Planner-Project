#!/usr/bin/env bash
#
# Sprint 3 Day 1 Study Insight Verification Runbook
#
# Purpose:
#   Verify that the StudyBuddy Sprint 3 Day 1 insight foundation is aligned
#   with the current Django project. This checks the installed insights app,
#   clean migrations, the persisted StudyInsight model, admin inspection,
#   deterministic AI/NLP contract documentation, and the focused insights tests.
#
# Execution instructions:
#   1. Run this file from anywhere inside the repository:
#
#        ./docs/sprint-runbook/sprint-3/sprint-3-day-1.sh
#
#   2. If the file is not executable, run:
#
#        chmod +x docs/sprint-runbook/sprint-3/sprint-3-day-1.sh
#
#   3. Docker Desktop or a compatible Docker daemon must be running.
#   4. The script builds/recreates the Docker Compose web container so checks
#      run against the same source and dependency environment as the app.
#
# Expected final receipt:
#   - Repository root verified.
#   - Sprint 3 Day 1 files exist.
#   - apps.insights is installed through InsightsConfig.
#   - StudyInsight imports and is registered with Django.
#   - Django system checks pass.
#   - insights migrations are clean and applied.
#   - StudyInsight table exists.
#   - StudyInsight fields match the current session-owned model.
#   - StudyInsight unique constraint is session + source_hash.
#   - StudyInsight admin exposes ownership through session.owner.
#   - AI/NLP contract document is present and aligned with current scope.
#   - apps/insights/tests/test_models.py passes with 7 tests.
#   - apps/insights tests pass with 9 tests.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_MODEL_TEST_COUNT=7
EXPECTED_INSIGHTS_TEST_COUNT=9

section() {
    printf '\n==> %s\n' "$1"
}

run() {
    printf '\n$ %s\n' "$*"
    "$@"
}

run_and_expect() {
    local expected="$1"
    shift

    printf '\n$ %s\n' "$*"
    local output
    output="$("$@" 2>&1)"
    printf '%s\n' "$output"

    if [[ "$output" != *"$expected"* ]]; then
        printf 'ERROR: Expected output to contain: %s\n' "$expected" >&2
        exit 1
    fi
}

section "Verify repository root"
run cd "$PROJECT_ROOT"

if [[ ! -f "$PROJECT_ROOT/manage.py" ]]; then
    printf 'ERROR: manage.py not found. Expected repository root: %s\n' "$PROJECT_ROOT" >&2
    exit 1
fi

printf 'Repository root: %s\n' "$PROJECT_ROOT"

section "Confirm Sprint 3 Day 1 files exist"
required_files=(
    "apps/insights/__init__.py"
    "apps/insights/apps.py"
    "apps/insights/models.py"
    "apps/insights/admin.py"
    "apps/insights/factories.py"
    "apps/insights/migrations/__init__.py"
    "apps/insights/migrations/0001_initial.py"
    "apps/insights/tests/test_admin.py"
    "apps/insights/tests/test_models.py"
    "docs/ai-nlp-contract.md"
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

section "Confirm insights app is installed"
run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.apps import apps
from django.conf import settings

assert "apps.insights.apps.InsightsConfig" in settings.INSTALLED_APPS
assert apps.is_installed("apps.insights")
assert apps.get_app_config("insights").name == "apps.insights"
assert apps.get_model("insights", "StudyInsight")

print("InsightsConfig is registered in INSTALLED_APPS")
print("apps.insights is installed")
print("StudyInsight model registered")
PY

section "Run Django system check"
run docker compose exec -T web python manage.py check --settings=config.settings.local

section "Confirm insights migrations are clean"
run docker compose exec -T web python manage.py makemigrations insights --check --dry-run --settings=config.settings.local

section "Apply database migrations"
run docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local

section "Confirm insights migration status"
run docker compose exec -T web python manage.py showmigrations insights --settings=config.settings.local

section "Confirm StudyInsight database table exists"
run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.db import connection

assert "insights_studyinsight" in connection.introspection.table_names()

print("insights_studyinsight table exists")
PY

section "Confirm StudyInsight model metadata"
run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from apps.insights.models import StudyInsight

field_names = sorted(field.name for field in StudyInsight._meta.fields)
expected_fields = [
    "confidence",
    "created_at",
    "explanation",
    "id",
    "keywords",
    "session",
    "source_hash",
    "summary",
    "updated_at",
]

constraint_names = [constraint.name for constraint in StudyInsight._meta.constraints]

assert field_names == expected_fields, field_names
assert "owner" not in field_names
assert constraint_names == ["unique_insight_per_session_source"], constraint_names

print("StudyInsight fields:", field_names)
print("StudyInsight does not store a separate owner field")
print("StudyInsight uniqueness is session + source_hash")
PY

section "Confirm StudyInsight validation rules"
run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.core.exceptions import ValidationError

from apps.insights.models import StudyInsight
from apps.sessions.models import StudySession
from django.contrib.auth import get_user_model

User = get_user_model()

user, _ = User.objects.get_or_create(
    email="sprint3.day1.verify@example.com",
    defaults={"username": "sprint3-day1-verify"},
)
user.set_password("temporary-test-password")
user.save()

session = StudySession.objects.create(
    owner=user,
    title="Sprint 3 Day 1 insight verification",
    subject="Django",
    duration_minutes=45,
)

valid_insight = StudyInsight(
    session=session,
    summary="Session notes highlight deterministic testing.",
    keywords=["django", "testing", "insights"],
    confidence=80,
    explanation="Keywords are ranked by deterministic term frequency.",
    source_hash="a" * 64,
)
valid_insight.full_clean()
valid_insight.save()

invalid_keywords = StudyInsight(
    session=session,
    summary="Invalid keyword shape.",
    keywords={"django": 3},
    confidence=50,
    explanation="This should fail validation.",
    source_hash="b" * 64,
)

try:
    invalid_keywords.full_clean()
except ValidationError:
    print("Invalid keyword shape rejected")
else:
    raise AssertionError("Invalid keyword shape was accepted")

invalid_source_hash = StudyInsight(
    session=session,
    summary="Invalid source hash.",
    keywords=["django"],
    confidence=50,
    explanation="This should fail validation.",
    source_hash="not-a-sha",
)

try:
    invalid_source_hash.full_clean()
except ValidationError:
    print("Invalid source hash length rejected")
else:
    raise AssertionError("Invalid source hash length was accepted")

print("Valid StudyInsight saved")
print("StudyInsight validation rules verified")
PY

section "Confirm StudyInsight admin inspection"
run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.contrib import admin

from apps.insights.admin import StudyInsightAdmin
from apps.insights.models import StudyInsight

insight = StudyInsight.objects.select_related("session", "session__owner").latest("id")
insight_admin = StudyInsightAdmin(StudyInsight, admin.site)

assert insight_admin.session_owner(insight) == insight.session.owner.email
assert insight_admin.keywords_preview(insight) == "django, testing, insights"

print("StudyInsight admin session owner verified")
print("StudyInsight admin keywords preview verified")
PY

section "Confirm AI/NLP contract document sections"
required_doc_sections=(
    "## Current Scope"
    "## Deterministic Contract"
    "## Keyword Extraction"
    "## Extractive Summary"
    "## Confidence Scoring"
    "## Persistence Rules"
    "## Permission Rules"
    "## Testing Contract"
)

for section_title in "${required_doc_sections[@]}"; do
    if ! grep -Fq "$section_title" "$PROJECT_ROOT/docs/ai-nlp-contract.md"; then
        printf 'ERROR: Missing contract section: %s\n' "$section_title" >&2
        exit 1
    fi

    printf 'FOUND: %s\n' "$section_title"
done

if grep -Fq "one insight per owner, session, and source hash" "$PROJECT_ROOT/docs/ai-nlp-contract.md"; then
    printf 'ERROR: Contract still contains stale owner-based uniqueness text.\n' >&2
    exit 1
fi

if ! grep -Fq 'StudyInsight` does not store a separate `owner` field' "$PROJECT_ROOT/docs/ai-nlp-contract.md"; then
    printf 'ERROR: Contract does not document session-owned StudyInsight ownership.\n' >&2
    exit 1
fi

printf 'AI/NLP contract document is aligned with current StudyInsight ownership.\n'

section "Run Sprint 3 Day 1 model tests"
run_and_expect "${EXPECTED_MODEL_TEST_COUNT} passed" \
    docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test \
    pytest apps/insights/tests/test_models.py -q

section "Run all current insights tests"
run_and_expect "${EXPECTED_INSIGHTS_TEST_COUNT} passed" \
    docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test \
    pytest apps/insights -q

section "Run full project test suite"
run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q

section "Final receipt"
printf 'Repository root verified.\n'
printf 'Sprint 3 Day 1 files verified.\n'
printf 'apps.insights installed through InsightsConfig.\n'
printf 'StudyInsight model registration verified.\n'
printf 'Django system check passed.\n'
printf 'insights migrations are clean and applied.\n'
printf 'insights_studyinsight table exists.\n'
printf 'StudyInsight fields match the current session-owned model.\n'
printf 'StudyInsight unique constraint is session + source_hash.\n'
printf 'StudyInsight validation rules verified.\n'
printf 'StudyInsight admin inspection verified.\n'
printf 'AI/NLP contract document verified.\n'
printf 'apps/insights/tests/test_models.py passes with %s tests.\n' "$EXPECTED_MODEL_TEST_COUNT"
printf 'apps/insights tests pass with %s tests.\n' "$EXPECTED_INSIGHTS_TEST_COUNT"
printf 'Sprint 3 Day 1 verification complete.\n'
