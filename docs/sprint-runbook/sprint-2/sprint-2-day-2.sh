#!/usr/bin/env bash
#
# Sprint 2 Day 2 Study Session Workflow Verification Runbook
#
# Purpose:
#   Verify that the StudyBuddy Sprint 2 Day 2 session list and create workflow
#   is aligned with the current Django project. This checks routing, templates,
#   form rendering, form cleanup, owner-scoped session queries, and the session
#   view test suite.
#
# Execution instructions:
#   1. Run this file from anywhere inside the repository:
#
#        ./docs/sprint-runbook/sprint-2/sprint-2-day-2.sh
#
#   2. If the file is not executable, run:
#
#        chmod +x docs/sprint-runbook/sprint-2/sprint-2-day-2.sh
#
#   3. Docker Desktop or a compatible Docker daemon must be running.
#   4. The script builds/recreates the Docker Compose web container so checks
#      run against the same source and dependency environment as the app.
#
# Expected final receipt:
#   - Repository root verified.
#   - Sprint 2 Day 2 files verified.
#   - Docker/PostgreSQL stack started.
#   - Django system check passed.
#   - study_sessions migrations are clean and applied.
#   - Session URL names verified.
#   - Session templates load successfully and use the project UI language.
#   - StudySessionForm fields and input cleanup verified.
#   - Anonymous session list access redirects.
#   - Authenticated list view is owner-scoped.
#   - Authenticated detail view loads for owned sessions.
#   - Authenticated create workflow saves a StudySession for the logged-in user.
#   - Invalid create submission is rejected.
#   - apps/sessions/tests/test_session_views.py passes with 7 tests.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_TEST_COUNT=7

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
  echo "ERROR: manage.py not found. Run this script from the repository root."
  exit 1
fi

echo "Repository root: $PROJECT_ROOT"

section "Confirm Sprint 2 Day 2 files exist"

required_files=(
  "apps/sessions/forms.py"
  "apps/sessions/selectors.py"
  "apps/sessions/views.py"
  "apps/sessions/urls.py"
  "apps/sessions/tests/test_session_views.py"
  "templates/sessions/session_list.html"
  "templates/sessions/session_form.html"
  "templates/sessions/session_detail.html"
  "templates/base.html"
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

section "Verify session URL names resolve"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.urls import reverse

routes = {
    "sessions:list": reverse("sessions:list"),
    "sessions:create": reverse("sessions:create"),
    "sessions:detail": reverse("sessions:detail", kwargs={"pk": 1}),
    "sessions:update": reverse("sessions:update", kwargs={"pk": 1}),
    "sessions:add_note": reverse("sessions:add_note", kwargs={"pk": 1}),
}

for name, path in routes.items():
    print(f"{name} -> {path}")

assert routes["sessions:list"] == "/sessions/"
assert routes["sessions:create"] == "/sessions/new/"
assert routes["sessions:detail"] == "/sessions/1/"
assert routes["sessions:update"] == "/sessions/1/edit/"
assert routes["sessions:add_note"] == "/sessions/1/notes/new/"

print("Session URL names verified")
PY

section "Verify session templates load and use project UI language"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from pathlib import Path

from django.conf import settings
from django.template.loader import get_template

required_tokens = {
    "sessions/session_list.html": [
        "container-ui",
        "btn-ui",
        "No study sessions yet.",
    ],
    "sessions/session_form.html": [
        "form-ui",
        "btn-ui",
        "Back to Study Sessions",
    ],
    "sessions/session_detail.html": [
        "form-ui",
        "btn-ui",
        "Add Note",
    ],
    "base.html": [
        "site-shell",
        "nav-link-ui",
        "Study Sessions",
    ],
}

for template_name, tokens in required_tokens.items():
    get_template(template_name)
    template_path = Path(settings.BASE_DIR) / "templates" / template_name
    source = template_path.read_text(encoding="utf-8")

    for token in tokens:
        assert token in source, f"{template_name} is missing project UI token: {token}"

    print(f"Template loaded and aligned: {template_name}")

print("Sprint 2 Day 2 templates verified")
PY

section "Verify StudySessionForm fields and input cleanup"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from apps.sessions.forms import StudySessionForm

form = StudySessionForm()

expected_fields = [
    "title",
    "subject",
    "status",
    "study_date",
    "duration_minutes",
]

actual_fields = list(form.fields.keys())

assert actual_fields == expected_fields, actual_fields

assert form.fields["title"].widget.attrs["placeholder"] == "Revise Django model relationships"
assert form.fields["subject"].widget.attrs["placeholder"] == "Django, statistics, biology"
assert form.fields["study_date"].widget.input_type == "date"
assert form.fields["duration_minutes"].widget.attrs["min"] == 1
assert form.fields["duration_minutes"].widget.attrs["max"] == 1440
assert form.fields["duration_minutes"].widget.attrs["placeholder"] == "90"

for field_name in expected_fields:
    widget_attrs = form.fields[field_name].widget.attrs
    assert "class" not in widget_attrs, f"{field_name} should use template-level form-ui styling"
    print(f"Verified form field: {field_name}")

cleaned_form = StudySessionForm(
    data={
        "title": "  Trimmed title  ",
        "subject": "  Django  ",
        "status": "planned",
        "study_date": "2026-05-11",
        "duration_minutes": "45",
    }
)

assert cleaned_form.is_valid(), cleaned_form.errors
assert cleaned_form.cleaned_data["title"] == "Trimmed title"
assert cleaned_form.cleaned_data["subject"] == "Django"

print("StudySessionForm fields and cleanup verified")
PY

section "Verify authenticated list and create workflow"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudySession

if "testserver" not in settings.ALLOWED_HOSTS:
    settings.ALLOWED_HOSTS.append("testserver")

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day2.verify").delete()

owner = User.objects.create_user(
    email="sprint2.day2.verify.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day2.verify.other@example.com",
    password="temporary-test-password",
)

owned_session = StudySession.objects.create(
    owner=owner,
    title="Owned verification session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

StudySession.objects.create(
    owner=other_user,
    title="Foreign verification session",
    subject="PostgreSQL",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=60,
)

anonymous_client = Client()
anonymous_response = anonymous_client.get(reverse("sessions:list"))
assert anonymous_response.status_code == 302
assert "/users/login/" in anonymous_response["Location"]
print("Anonymous session list access redirects")

client = Client()
client.force_login(owner)

list_response = client.get(reverse("sessions:list"))
assert list_response.status_code == 200

content = list_response.content.decode()
assert owned_session.title in content
assert "Foreign verification session" not in content
print("Authenticated session list is owner-scoped")

detail_response = client.get(reverse("sessions:detail", kwargs={"pk": owned_session.pk}))
assert detail_response.status_code == 200
assert owned_session.title in detail_response.content.decode()
print("Authenticated session detail loads")

create_page_response = client.get(reverse("sessions:create"))
assert create_page_response.status_code == 200
assert "Create study session" in create_page_response.content.decode()
print("Authenticated create page loads")

create_response = client.post(
    reverse("sessions:create"),
    {
        "title": "  Created through Day 2 runbook  ",
        "subject": "  Django  ",
        "status": StudySession.Status.PLANNED,
        "study_date": timezone.localdate().isoformat(),
        "duration_minutes": "50",
    },
)

created_session = StudySession.objects.get(
    owner=owner,
    title="Created through Day 2 runbook",
)

assert created_session.subject == "Django"
assert create_response.status_code == 302
assert create_response["Location"] == reverse(
    "sessions:detail",
    kwargs={"pk": created_session.pk},
)

print("Authenticated create workflow saves owner-scoped StudySession")
print("Created session id:", created_session.pk)
PY

section "Verify invalid create submission is rejected"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudySession

if "testserver" not in settings.ALLOWED_HOSTS:
    settings.ALLOWED_HOSTS.append("testserver")

User = get_user_model()
user = User.objects.get(email="sprint2.day2.verify.owner@example.com")

client = Client()
client.force_login(user)

before_count = StudySession.objects.filter(owner=user).count()

response = client.post(
    reverse("sessions:create"),
    {
        "title": "Invalid Day 2 duration",
        "subject": "Django",
        "status": StudySession.Status.PLANNED,
        "study_date": timezone.localdate().isoformat(),
        "duration_minutes": "0",
    },
)

after_count = StudySession.objects.filter(owner=user).count()

assert response.status_code == 200
assert before_count == after_count
assert "Ensure this value is greater than or equal to 1" in response.content.decode()

print("Invalid create submission rejected")
print("Session count unchanged:", after_count)
PY

section "Run Sprint 2 Day 2 session view tests"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions/tests/test_session_views.py -q

section "Final receipt"

echo "Repository root verified."
echo "Sprint 2 Day 2 files verified."
echo "Docker/PostgreSQL stack started."
echo "Django system check passed."
echo "study_sessions migrations are clean and applied."
echo "Session URL names verified."
echo "Session templates load successfully and use the project UI language."
echo "StudySessionForm fields and input cleanup verified."
echo "Anonymous session list access redirects."
echo "Authenticated list view is owner-scoped."
echo "Authenticated detail view loads for owned sessions."
echo "Authenticated create workflow saves a StudySession for the logged-in user."
echo "Invalid create submission is rejected."
printf 'apps/sessions/tests/test_session_views.py passes with %s tests.\n' "$EXPECTED_TEST_COUNT"
echo "Sprint 2 Day 2 verification complete."
