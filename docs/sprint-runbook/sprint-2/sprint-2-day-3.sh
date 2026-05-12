#!/usr/bin/env bash
#
# Sprint 2 Day 3 Session Detail, Update, and Ownership Verification Runbook
#
# Purpose:
#   Verify that the StudyBuddy Sprint 2 Day 3 study-session detail and update
#   workflow is aligned with the current Django project. This runbook checks
#   routing, templates, selector-level ownership protection, update form
#   behavior, note maintenance routes, and the sessions test suite.
#
# Execution instructions:
#   1. Run this file from anywhere inside the repository:
#
#        ./docs/sprint-runbook/sprint-2/sprint-2-day-3.sh
#
#   2. If the file is not executable, run:
#
#        chmod +x docs/sprint-runbook/sprint-2/sprint-2-day-3.sh
#
#   3. Docker Desktop or a compatible Docker daemon must be running.
#   4. The script builds/recreates the Docker Compose web container so checks
#      run against the same source and dependency environment as the app.
#   5. The script writes temporary verification records to the local Docker
#      PostgreSQL database using email prefixes beginning with "sprint2.day3".
#
# Expected final receipt:
#   - Repository root verified.
#   - Sprint 2 Day 3 files verified.
#   - Docker/PostgreSQL stack started.
#   - Django system check passed.
#   - study_sessions migrations are clean and applied.
#   - Session and note URL names verified.
#   - Session detail and form templates load successfully.
#   - Selector ownership behaviour verified.
#   - Owned session detail page loads.
#   - Cross-user detail access returns 404.
#   - Owned session update page loads.
#   - Owned session update workflow saves changes.
#   - Invalid update submission is rejected.
#   - Cross-user update access returns 404 and leaves foreign data unchanged.
#   - Owned note update and delete workflows work.
#   - Cross-user note update and delete access returns 404.
#   - Sprint 2 Day 3 permission tests pass.
#   - Sprint 2 Day 3 update tests pass.
#   - Sprint 2 Day 3 note tests pass.
#   - apps/sessions test suite passes.
#   - Sprint 2 Day 3 verification complete.

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

section "Confirm Sprint 2 Day 3 files exist"

required_files=(
  "apps/sessions/forms.py"
  "apps/sessions/selectors.py"
  "apps/sessions/views.py"
  "apps/sessions/urls.py"
  "apps/sessions/tests/test_session_permissions.py"
  "apps/sessions/tests/test_session_update.py"
  "apps/sessions/tests/test_session_notes.py"
  "templates/sessions/session_detail.html"
  "templates/sessions/session_form.html"
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

section "Verify session and note URL names resolve"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.urls import reverse

routes = {
    "sessions:detail": reverse("sessions:detail", kwargs={"pk": 1}),
    "sessions:update": reverse("sessions:update", kwargs={"pk": 1}),
    "sessions:add_note": reverse("sessions:add_note", kwargs={"pk": 1}),
    "sessions:update_note": reverse(
        "sessions:update_note",
        kwargs={"pk": 1, "note_pk": 2},
    ),
    "sessions:delete_note": reverse(
        "sessions:delete_note",
        kwargs={"pk": 1, "note_pk": 2},
    ),
}

for name, path in routes.items():
    print(f"{name} -> {path}")

assert routes["sessions:detail"] == "/sessions/1/"
assert routes["sessions:update"] == "/sessions/1/edit/"
assert routes["sessions:add_note"] == "/sessions/1/notes/new/"
assert routes["sessions:update_note"] == "/sessions/1/notes/2/edit/"
assert routes["sessions:delete_note"] == "/sessions/1/notes/2/delete/"

print("Session and note URL names verified")
PY

section "Verify session detail and form templates load"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from pathlib import Path

from django.conf import settings
from django.template.loader import get_template

required_tokens = {
    "sessions/session_detail.html": [
        "container-ui",
        "Edit Session",
        "Add Note",
        "Edit note",
        "Delete Note",
        "sessions:update_note",
        "sessions:delete_note",
    ],
    "sessions/session_form.html": [
        "form-ui",
        "Session Details",
        "submit_label",
        "Back to Study Sessions",
    ],
    "base.html": [
        "site-shell",
        "Study Sessions",
    ],
}

for template_name, tokens in required_tokens.items():
    get_template(template_name)
    template_path = Path(settings.BASE_DIR) / "templates" / template_name
    source = template_path.read_text(encoding="utf-8")

    for token in tokens:
        assert token in source, f"{template_name} is missing expected token: {token}"

    print(f"Template loaded and aligned: {template_name}")

print("Sprint 2 Day 3 templates verified")
PY

section "Verify selector ownership behaviour"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.contrib.auth import get_user_model
from django.http import Http404
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession
from apps.sessions.selectors import (
    get_note_for_user_or_404,
    get_session_for_user_or_404,
    get_sessions_for_user,
)

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day3.selector").delete()

owner = User.objects.create_user(
    email="sprint2.day3.selector.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day3.selector.other@example.com",
    password="temporary-test-password",
)

owned_session = StudySession.objects.create(
    owner=owner,
    title="Owned selector session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=40,
)

foreign_session = StudySession.objects.create(
    owner=other_user,
    title="Foreign selector session",
    subject="PostgreSQL",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=55,
)

owned_note = StudyNote.objects.create(
    session=owned_session,
    content="Owned selector note with enough detail.",
)

foreign_note = StudyNote.objects.create(
    session=foreign_session,
    content="Foreign selector note with enough detail.",
)

owner_sessions = get_sessions_for_user(owner)

assert owned_session in owner_sessions
assert foreign_session not in owner_sessions

resolved_session = get_session_for_user_or_404(owner, owned_session.pk)
assert resolved_session == owned_session

resolved_note = get_note_for_user_or_404(owner, owned_session.pk, owned_note.pk)
assert resolved_note == owned_note

for label, callback in {
    "foreign session lookup": lambda: get_session_for_user_or_404(owner, foreign_session.pk),
    "foreign note lookup": lambda: get_note_for_user_or_404(owner, foreign_session.pk, foreign_note.pk),
    "wrong parent session note lookup": lambda: get_note_for_user_or_404(owner, foreign_session.pk, owned_note.pk),
}.items():
    try:
        callback()
    except Http404:
        print(f"{label} returns 404")
    else:
        raise AssertionError(f"{label} did not return 404")

print("Selector ownership behaviour verified")
PY

section "Verify owned session detail page loads"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

if "testserver" not in settings.ALLOWED_HOSTS:
    settings.ALLOWED_HOSTS.append("testserver")

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day3.detail").delete()

owner = User.objects.create_user(
    email="sprint2.day3.detail.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Owned detail verification session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

note = StudyNote.objects.create(
    session=session,
    content="Owned detail note with enough detail.",
)

client = Client()
client.force_login(owner)

response = client.get(reverse("sessions:detail", kwargs={"pk": session.pk}))
content = response.content.decode()

assert response.status_code == 200
assert "Owned detail verification session" in content
assert reverse("sessions:update", kwargs={"pk": session.pk}) in content
assert reverse("sessions:update_note", kwargs={"pk": session.pk, "note_pk": note.pk}) in content
assert reverse("sessions:delete_note", kwargs={"pk": session.pk, "note_pk": note.pk}) in content

print("Owned session detail page loads")
print("Detail status code:", response.status_code)
PY

section "Verify cross-user detail access returns 404"

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
User.objects.filter(email__startswith="sprint2.day3.detail403").delete()

owner = User.objects.create_user(
    email="sprint2.day3.detail403.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day3.detail403.other@example.com",
    password="temporary-test-password",
)

foreign_session = StudySession.objects.create(
    owner=other_user,
    title="Foreign detail verification session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

client = Client()
client.force_login(owner)

response = client.get(reverse("sessions:detail", kwargs={"pk": foreign_session.pk}))

assert response.status_code == 404

print("Cross-user detail access returns 404")
print("Detail protection status code:", response.status_code)
PY

section "Verify owned session update page loads"

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
User.objects.filter(email__startswith="sprint2.day3.update.page").delete()

owner = User.objects.create_user(
    email="sprint2.day3.update.page.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Owned update page verification session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

client = Client()
client.force_login(owner)

response = client.get(reverse("sessions:update", kwargs={"pk": session.pk}))
content = response.content.decode()

assert response.status_code == 200
assert "Edit study session" in content
assert "Owned update page verification session" in content

print("Owned session update page loads")
print("Update page status code:", response.status_code)
PY

section "Verify owned session update workflow saves changes"

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
User.objects.filter(email__startswith="sprint2.day3.update.save").delete()

owner = User.objects.create_user(
    email="sprint2.day3.update.save.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Original Day 3 update title",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

client = Client()
client.force_login(owner)

response = client.post(
    reverse("sessions:update", kwargs={"pk": session.pk}),
    {
        "title": "Updated Day 3 verification title",
        "subject": "PostgreSQL",
        "status": StudySession.Status.IN_PROGRESS,
        "study_date": timezone.localdate().isoformat(),
        "duration_minutes": "90",
    },
)

session.refresh_from_db()

assert response.status_code == 302
assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
assert session.title == "Updated Day 3 verification title"
assert session.subject == "PostgreSQL"
assert session.status == StudySession.Status.IN_PROGRESS
assert session.duration_minutes == 90

print("Owned session update workflow saves changes")
print("Updated session id:", session.pk)
PY

section "Verify invalid update submission is rejected"

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
User.objects.filter(email__startswith="sprint2.day3.update.invalid").delete()

owner = User.objects.create_user(
    email="sprint2.day3.update.invalid.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Original invalid update title",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

client = Client()
client.force_login(owner)

response = client.post(
    reverse("sessions:update", kwargs={"pk": session.pk}),
    {
        "title": "Invalid updated title",
        "subject": "Django",
        "status": StudySession.Status.PLANNED,
        "study_date": timezone.localdate().isoformat(),
        "duration_minutes": "0",
    },
)

session.refresh_from_db()

assert response.status_code == 200
assert session.title == "Original invalid update title"
assert session.duration_minutes == 45
assert "Ensure this value is greater than or equal to 1" in response.content.decode()

print("Invalid update submission rejected")
print("Session remains unchanged:", session.title)
PY

section "Verify cross-user update access returns 404"

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
User.objects.filter(email__startswith="sprint2.day3.update403").delete()

owner = User.objects.create_user(
    email="sprint2.day3.update403.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day3.update403.other@example.com",
    password="temporary-test-password",
)

foreign_session = StudySession.objects.create(
    owner=other_user,
    title="Foreign update verification session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

client = Client()
client.force_login(owner)

get_response = client.get(reverse("sessions:update", kwargs={"pk": foreign_session.pk}))
post_response = client.post(
    reverse("sessions:update", kwargs={"pk": foreign_session.pk}),
    {
        "title": "Attempted foreign update",
        "subject": "Django",
        "status": StudySession.Status.COMPLETED,
        "study_date": timezone.localdate().isoformat(),
        "duration_minutes": "120",
    },
)

foreign_session.refresh_from_db()

assert get_response.status_code == 404
assert post_response.status_code == 404
assert foreign_session.title == "Foreign update verification session"
assert foreign_session.status == StudySession.Status.PLANNED
assert foreign_session.duration_minutes == 45

print("Cross-user update access returns 404")
print("Foreign session remains unchanged")
PY

section "Verify owned note update and delete workflows"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

if "testserver" not in settings.ALLOWED_HOSTS:
    settings.ALLOWED_HOSTS.append("testserver")

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day3.note.owner").delete()

owner = User.objects.create_user(
    email="sprint2.day3.note.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Owned note workflow session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

note = StudyNote.objects.create(
    session=session,
    content="Original owned note content.",
)

client = Client()
client.force_login(owner)

update_response = client.post(
    reverse("sessions:update_note", kwargs={"pk": session.pk, "note_pk": note.pk}),
    {"content": "Updated owned note content with enough detail."},
)

note.refresh_from_db()

assert update_response.status_code == 302
assert update_response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
assert note.content == "Updated owned note content with enough detail."

invalid_response = client.post(
    reverse("sessions:update_note", kwargs={"pk": session.pk, "note_pk": note.pk}),
    {"content": "short"},
)

note.refresh_from_db()

assert invalid_response.status_code == 400
assert "Study notes must contain at least 10 characters." in invalid_response.content.decode()
assert note.content == "Updated owned note content with enough detail."

delete_response = client.post(
    reverse("sessions:delete_note", kwargs={"pk": session.pk, "note_pk": note.pk}),
)

assert delete_response.status_code == 302
assert delete_response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
assert not StudyNote.objects.filter(pk=note.pk).exists()

print("Owned note update and delete workflows work")
PY

section "Verify cross-user note update and delete access returns 404"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

if "testserver" not in settings.ALLOWED_HOSTS:
    settings.ALLOWED_HOSTS.append("testserver")

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day3.note403").delete()

owner = User.objects.create_user(
    email="sprint2.day3.note403.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day3.note403.other@example.com",
    password="temporary-test-password",
)

foreign_session = StudySession.objects.create(
    owner=other_user,
    title="Foreign note verification session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

foreign_note = StudyNote.objects.create(
    session=foreign_session,
    content="Foreign note content with enough detail.",
)

client = Client()
client.force_login(owner)

update_response = client.post(
    reverse(
        "sessions:update_note",
        kwargs={"pk": foreign_session.pk, "note_pk": foreign_note.pk},
    ),
    {"content": "Attempted foreign note update."},
)

delete_response = client.post(
    reverse(
        "sessions:delete_note",
        kwargs={"pk": foreign_session.pk, "note_pk": foreign_note.pk},
    ),
)

foreign_note.refresh_from_db()

assert update_response.status_code == 404
assert delete_response.status_code == 404
assert foreign_note.content == "Foreign note content with enough detail."
assert StudyNote.objects.filter(pk=foreign_note.pk).exists()

print("Cross-user note update and delete access returns 404")
print("Foreign note remains unchanged")
PY

section "Run Sprint 2 Day 3 permission tests"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions/tests/test_session_permissions.py -q

section "Run Sprint 2 Day 3 update tests"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions/tests/test_session_update.py -q

section "Run Sprint 2 Day 3 note tests"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions/tests/test_session_notes.py -q

section "Run full Sprint 2 sessions test suite"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions -q

section "Final receipt"

echo "Repository root verified."
echo "Sprint 2 Day 3 files verified."
echo "Docker/PostgreSQL stack started."
echo "Django system check passed."
echo "study_sessions migrations are clean and applied."
echo "Session and note URL names verified."
echo "Session detail and form templates load successfully."
echo "Selector ownership behaviour verified."
echo "Owned session detail page loads."
echo "Cross-user detail access returns 404."
echo "Owned session update page loads."
echo "Owned session update workflow saves changes."
echo "Invalid update submission is rejected."
echo "Cross-user update access returns 404 and leaves foreign data unchanged."
echo "Owned note update and delete workflows work."
echo "Cross-user note update and delete access returns 404."
echo "Sprint 2 Day 3 permission tests pass."
echo "Sprint 2 Day 3 update tests pass."
echo "Sprint 2 Day 3 note tests pass."
echo "apps/sessions test suite passes."
echo "Sprint 2 Day 3 verification complete."
