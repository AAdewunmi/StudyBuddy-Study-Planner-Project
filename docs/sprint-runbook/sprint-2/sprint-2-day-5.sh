#!/usr/bin/env bash
#
# Sprint 2 Day 5 Dashboard Metrics Verification Runbook
#
# Purpose:
#   Verify that the StudyBuddy Sprint 2 Day 5 dashboard metrics workflow is
#   aligned with the current Django project. This runbook checks user-scoped
#   selectors, aggregate session services, dashboard context composition,
#   data-backed dashboard rendering, template aggregate boundaries, design
#   system purity, documentation, and the focused dashboard/session tests.
#
# Execution instructions:
#   1. Run this file from anywhere inside the repository:
#
#        ./docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
#
#   2. If the file is not executable, run:
#
#        chmod +x docs/sprint-runbook/sprint-2/sprint-2-day-5.sh
#
#   3. Docker Desktop or a compatible Docker daemon must be running.
#   4. The script builds/recreates the Docker Compose web container so checks
#      run against the current source tree and dependency environment.
#   5. The script writes temporary verification records to the local Docker
#      PostgreSQL database using email prefixes beginning with "sprint2.day5".
#
# Expected final receipt:
#   - Repository root verified.
#   - Sprint 2 Day 5 files verified.
#   - Docker/PostgreSQL stack started.
#   - Django system check passed.
#   - study_sessions migrations are clean and applied.
#   - Dashboard URL verified.
#   - Dashboard templates load successfully.
#   - Session selector functions verified.
#   - Session metrics service calculates user-scoped aggregates.
#   - Empty metrics service result verified.
#   - Dashboard context service verified.
#   - Anonymous dashboard access redirects.
#   - Dashboard empty state verified.
#   - Dashboard aggregate rendering verified.
#   - Dashboard template renders prepared metrics only.
#   - Design-system template purity verified.
#   - Dashboard metrics documentation verified.
#   - Sprint 2 Day 5 dashboard metric tests pass.
#   - Dashboard test suite passes.
#   - Sessions test suite passes.
#   - Sprint 2 dashboard and sessions test suites pass.
#   - Sprint 2 Day 5 verification complete.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"

section() {
  printf "\n==> %s\n\n" "$1"
}

run() {
  printf "$ %s\n" "$*"
  "$@"
}

section "Verify repository root"

run cd "$PROJECT_ROOT"

if [ ! -f "manage.py" ]; then
  echo "ERROR: manage.py not found. Run this script from inside the repository."
  exit 1
fi

echo "Repository root: $PROJECT_ROOT"

section "Confirm Sprint 2 Day 5 files exist"

required_files=(
  "apps/sessions/selectors.py"
  "apps/sessions/services.py"
  "apps/dashboard/services.py"
  "apps/dashboard/views.py"
  "apps/dashboard/tests/test_dashboard_metrics.py"
  "templates/dashboard/index.html"
  "templates/base.html"
  "static/css/theme.css"
  "docs/domain-model.md"
  "docs/design-system.md"
  "config/urls.py"
)

for file in "${required_files[@]}"; do
  if [ ! -f "$file" ]; then
    echo "ERROR: Missing required file: $file"
    exit 1
  fi

  echo "FOUND: $file"
done

section "Build and start Docker/PostgreSQL stack"

run docker compose up -d --build
run docker compose ps

section "Run Django system check"

run docker compose exec -T web python manage.py check --settings=config.settings.local

section "Confirm sessions migrations are clean"

run docker compose exec -T web python manage.py makemigrations study_sessions --check --dry-run --settings=config.settings.local

section "Apply database migrations"

run docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local

section "Verify dashboard URL resolves"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.urls import reverse

dashboard_path = reverse("dashboard:index")

assert dashboard_path == "/dashboard/", dashboard_path

print("dashboard:index ->", dashboard_path)
print("Dashboard URL verified")
PY

section "Verify dashboard template loads"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.template.loader import get_template

templates = [
    "dashboard/index.html",
    "base.html",
]

for template_name in templates:
    get_template(template_name)
    print(f"Template loaded: {template_name}")

print("Dashboard templates verified")
PY

section "Verify session selector functions"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.contrib.auth import get_user_model
from django.http import Http404
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession
from apps.sessions.selectors import (
    get_notes_for_session,
    get_notes_for_user,
    get_recent_sessions_for_user,
    get_session_for_user_or_404,
    get_sessions_for_user,
)

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day5.selectors").delete()

owner = User.objects.create_user(
    email="sprint2.day5.selectors.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day5.selectors.other@example.com",
    password="temporary-test-password",
)

owned_session = StudySession.objects.create(
    owner=owner,
    title="Owned selector metrics session",
    subject="Django",
    status=StudySession.Status.COMPLETED,
    study_date=timezone.localdate(),
    duration_minutes=60,
)

foreign_session = StudySession.objects.create(
    owner=other_user,
    title="Foreign selector metrics session",
    subject="PostgreSQL",
    status=StudySession.Status.COMPLETED,
    study_date=timezone.localdate(),
    duration_minutes=300,
)

note = StudyNote.objects.create(
    session=owned_session,
    content="Selector verification note with enough useful content.",
)

owner_sessions = get_sessions_for_user(owner)
recent_sessions = get_recent_sessions_for_user(owner, limit=5)
session_notes = get_notes_for_session(owned_session)
owner_notes = get_notes_for_user(owner)

assert owned_session in owner_sessions
assert foreign_session not in owner_sessions
assert owned_session in recent_sessions
assert note in session_notes
assert note in owner_notes
assert get_session_for_user_or_404(owner, owned_session.pk) == owned_session

try:
    get_session_for_user_or_404(owner, foreign_session.pk)
except Http404:
    print("Foreign session lookup returns 404")
else:
    raise AssertionError("Foreign session lookup did not return 404")

print("Session selectors verified")
print("Owner session count:", owner_sessions.count())
print("Recent session count:", len(recent_sessions))
print("Owned note count:", owner_notes.count())
PY

section "Verify session metrics service calculates aggregates"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession
from apps.sessions.services import build_session_metrics_for_user

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day5.metrics").delete()

owner = User.objects.create_user(
    email="sprint2.day5.metrics.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day5.metrics.other@example.com",
    password="temporary-test-password",
)

completed_session = StudySession.objects.create(
    owner=owner,
    title="Completed metrics session",
    subject="Django",
    status=StudySession.Status.COMPLETED,
    study_date=timezone.localdate(),
    duration_minutes=90,
)

planned_session = StudySession.objects.create(
    owner=owner,
    title="Planned metrics session",
    subject="PostgreSQL",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate() - timedelta(days=1),
    duration_minutes=30,
)

StudySession.objects.create(
    owner=other_user,
    title="Foreign metrics session",
    subject="Algorithms",
    status=StudySession.Status.COMPLETED,
    study_date=timezone.localdate(),
    duration_minutes=999,
)

StudyNote.objects.create(
    session=completed_session,
    content="First dashboard metric note with enough useful content.",
)

StudyNote.objects.create(
    session=planned_session,
    content="Second dashboard metric note with enough useful content.",
)

metrics = build_session_metrics_for_user(owner)

assert metrics.total_sessions == 2
assert metrics.completed_sessions == 1
assert metrics.total_minutes == 120
assert metrics.note_count == 2
assert len(metrics.recent_sessions) == 2
assert all(session.owner == owner for session in metrics.recent_sessions)

print("Session metrics service verified")
print("Total sessions:", metrics.total_sessions)
print("Completed sessions:", metrics.completed_sessions)
print("Total study minutes:", metrics.total_minutes)
print("Note count:", metrics.note_count)
print("Recent session count:", len(metrics.recent_sessions))
PY

section "Verify empty metrics service result for new user"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.contrib.auth import get_user_model

from apps.sessions.services import build_session_metrics_for_user

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day5.empty").delete()

new_user = User.objects.create_user(
    email="sprint2.day5.empty.owner@example.com",
    password="temporary-test-password",
)

metrics = build_session_metrics_for_user(new_user)

assert metrics.total_sessions == 0
assert metrics.completed_sessions == 0
assert metrics.total_minutes == 0
assert metrics.note_count == 0
assert metrics.recent_sessions == []

print("Empty metrics service result verified")
print("New user totals are zero")
PY

section "Verify dashboard context service"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.contrib.auth import get_user_model
from django.utils import timezone

from apps.dashboard.services import build_dashboard_context
from apps.sessions.models import StudyNote, StudySession

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day5.context").delete()

owner = User.objects.create_user(
    email="sprint2.day5.context.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Dashboard context verification session",
    subject="Django",
    status=StudySession.Status.COMPLETED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

StudyNote.objects.create(
    session=session,
    content="Dashboard context verification note with useful detail.",
)

context = build_dashboard_context(owner)

assert "metrics" in context
assert "recent_activity" in context
assert "roles" in context
assert context["metrics"].total_sessions == 1
assert context["metrics"].completed_sessions == 1
assert context["metrics"].total_minutes == 45
assert context["metrics"].note_count == 1
assert context["recent_activity"][0] == session

print("Dashboard context service verified")
print("Context keys:", ", ".join(sorted(context.keys())))
PY

section "Verify dashboard view redirects anonymous users"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.test import Client
from django.urls import reverse

if "testserver" not in settings.ALLOWED_HOSTS:
    settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

client = Client()

response = client.get(reverse("dashboard:index"))

assert response.status_code == 302
assert reverse("users:login") in response["Location"]

print("Anonymous dashboard access redirects")
print("Redirect location:", response["Location"])
PY

section "Verify dashboard renders empty state for new user"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse

if "testserver" not in settings.ALLOWED_HOSTS:
    settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day5.emptyview").delete()

user = User.objects.create_user(
    email="sprint2.day5.emptyview.owner@example.com",
    password="temporary-test-password",
)

client = Client()
client.force_login(user)

response = client.get(reverse("dashboard:index"))
content = response.content.decode()

assert response.status_code == 200
assert "No study activity yet" in content
assert "No study sessions yet" in content
assert reverse("sessions:create") in content

print("Dashboard empty state verified")
print("Dashboard status code:", response.status_code)
PY

section "Verify dashboard renders aggregate metrics for authenticated user"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

if "testserver" not in settings.ALLOWED_HOSTS:
    settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day5.dashboard").delete()

owner = User.objects.create_user(
    email="sprint2.day5.dashboard.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day5.dashboard.other@example.com",
    password="temporary-test-password",
)

completed_session = StudySession.objects.create(
    owner=owner,
    title="Rendered completed dashboard session",
    subject="Django",
    status=StudySession.Status.COMPLETED,
    study_date=timezone.localdate(),
    duration_minutes=75,
)

planned_session = StudySession.objects.create(
    owner=owner,
    title="Rendered planned dashboard session",
    subject="PostgreSQL",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate() - timedelta(days=1),
    duration_minutes=25,
)

StudySession.objects.create(
    owner=other_user,
    title="Foreign dashboard session should not render",
    subject="Algorithms",
    status=StudySession.Status.COMPLETED,
    study_date=timezone.localdate(),
    duration_minutes=888,
)

StudyNote.objects.create(
    session=completed_session,
    content="Dashboard rendered note one with useful content.",
)

StudyNote.objects.create(
    session=planned_session,
    content="Dashboard rendered note two with useful content.",
)

client = Client()
client.force_login(owner)

response = client.get(reverse("dashboard:index"))
content = response.content.decode()

assert response.status_code == 200
assert "Total sessions" in content
assert "Completed" in content
assert "Study minutes" in content
assert "Notes" in content
assert "Rendered completed dashboard session" in content
assert "Rendered planned dashboard session" in content
assert "Foreign dashboard session should not render" not in content
assert "100" in content
assert "888" not in content

print("Dashboard aggregate rendering verified")
print("Expected total sessions: 2")
print("Expected completed sessions: 1")
print("Expected total study minutes: 100")
print("Expected note count: 2")
PY

section "Verify dashboard template renders prepared metrics only"

run docker compose exec -T web python - <<'PY'
from pathlib import Path

content = Path("templates/dashboard/index.html").read_text(encoding="utf-8")

for forbidden_fragment in [
    ".count",
    "|length",
    "forloop.counter",
    "dictsort",
    "regroup",
]:
    assert forbidden_fragment not in content, (
        "Dashboard template appears to calculate aggregate data directly: "
        f"{forbidden_fragment}"
    )

required_fragments = [
    "metrics.total_sessions",
    "metrics.completed_sessions",
    "metrics.total_minutes",
    "metrics.note_count",
    "recent_activity",
]

for required_fragment in required_fragments:
    assert required_fragment in content, f"Missing dashboard fragment: {required_fragment}"
    print(f"Dashboard fragment found: {required_fragment}")

print("Dashboard template renders prepared metrics only")
PY

section "Verify design-system template purity"

run docker compose exec -T web python - <<'PY'
from pathlib import Path

paths = [
    *Path("templates").glob("*.html"),
    *Path("templates").glob("*/*.html"),
]

for path in paths:
    content = path.read_text(encoding="utf-8")
    if path.name != "base.html":
        assert '{% extends "base.html" %}' in content, f"{path} does not extend base.html"

    for forbidden_fragment in [
        "bootstrap",
        "alert alert-",
        "btn btn",
        "row g-",
        "col-md",
        "list-group",
        "shadow-sm",
        "display-6",
        "style=",
        "data-bs",
    ]:
        assert forbidden_fragment not in content, (
            f"Template design-system violation in {path}: {forbidden_fragment}"
        )

theme = Path("static/css/theme.css").read_text(encoding="utf-8")
for required_fragment in [
    ".message-ui",
    ".message-ui-success",
    ".card-ui",
    ".btn-ui",
    ".metric-value",
    ".quote-card",
]:
    assert required_fragment in theme, f"Missing theme CSS fragment: {required_fragment}"
    print(f"Theme CSS fragment found: {required_fragment}")

print("Design-system template purity verified")
PY

section "Verify dashboard metrics documentation"

run docker compose exec -T web python - <<'PY'
from pathlib import Path

content = Path("docs/design-system.md").read_text(encoding="utf-8")

required_phrases = [
    "Authenticated Dashboard",
    "metrics.total_sessions",
    "metrics.completed_sessions",
    "metrics.total_minutes",
    "metrics.note_count",
    "recent_activity",
    "apps/sessions/services.py",
    "templates/dashboard/index.html",
]

for phrase in required_phrases:
    assert phrase in content, f"Missing documentation phrase: {phrase}"
    print(f"Documentation phrase found: {phrase}")

print("Dashboard metrics documentation verified")
PY

section "Run Sprint 2 Day 5 dashboard metric tests"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests/test_dashboard_metrics.py -q

section "Run dashboard test suite"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests -q

section "Run sessions test suite"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions/tests -q

section "Run Sprint 2 dashboard and sessions test suites"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/dashboard/tests apps/sessions/tests -q

section "Final receipt"

echo "Repository root verified."
echo "Sprint 2 Day 5 files verified."
echo "Docker/PostgreSQL stack started."
echo "Django system check passed."
echo "study_sessions migrations are clean and applied."
echo "Dashboard URL verified."
echo "Dashboard templates load successfully."
echo "Session selector functions verified."
echo "Session metrics service calculates user-scoped aggregates."
echo "Empty metrics service result verified."
echo "Dashboard context service verified."
echo "Anonymous dashboard access redirects."
echo "Dashboard empty state verified."
echo "Dashboard aggregate rendering verified."
echo "Dashboard template renders prepared metrics only."
echo "Design-system template purity verified."
echo "Dashboard metrics documentation verified."
echo "Sprint 2 Day 5 dashboard metric tests pass."
echo "Dashboard test suite passes."
echo "Sessions test suite passes."
echo "Sprint 2 dashboard and sessions test suites pass."
echo "Sprint 2 Day 5 verification complete."
