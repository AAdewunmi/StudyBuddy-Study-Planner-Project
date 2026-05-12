#!/usr/bin/env bash
#
# Sprint 2 Day 4 Note Capture and Ownership Verification Runbook
#
# Purpose:
#   Verify that the StudyBuddy Sprint 2 Day 4 note workflow is aligned with the
#   current Django project. This runbook checks the StudyNote model, form,
#   project-styled session detail UI, note create/update/delete routes,
#   authenticated ownership boundaries, documentation, and both note test files.
#
# Execution instructions:
#   1. Run this file from anywhere inside the repository:
#
#        ./docs/sprint-runbook/sprint-2/sprint-2-day-4.sh
#
#   2. If the file is not executable, run:
#
#        chmod +x docs/sprint-runbook/sprint-2/sprint-2-day-4.sh
#
#   3. Docker Desktop or a compatible Docker daemon must be running.
#   4. The script builds/recreates the Docker Compose web container so checks
#      run against the same source and dependency environment as the app.
#   5. The script writes temporary verification records to the local Docker
#      PostgreSQL database using email prefixes beginning with "sprint2.day4".
#
# Expected final receipt:
#   - Repository root verified.
#   - Sprint 2 Day 4 files verified.
#   - Docker/PostgreSQL stack started.
#   - Django system check passed.
#   - study_sessions migrations are clean and applied.
#   - StudyNote model fields and metadata verified.
#   - StudyNote validation rules verified.
#   - Note URL names verified.
#   - StudyNoteForm fields and project styling verified.
#   - Session detail renders note capture UI.
#   - Owned note creation workflow saves StudyNote.
#   - New notes appear on session detail.
#   - Short note submission is rejected.
#   - Cross-user note creation returns 404.
#   - Owned note update workflow saves changes.
#   - Invalid note update is rejected.
#   - Owned note delete workflow removes StudyNote.
#   - Cross-user note update and delete return 404.
#   - Wrong parent session note update returns 404.
#   - Study note documentation verified.
#   - Sprint 2 Day 4 direct note tests pass.
#   - Sprint 2 Day 4 note maintenance tests pass.
#   - apps/sessions test suite passes.
#   - Sprint 2 Day 4 verification complete.

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

section "Confirm Sprint 2 Day 4 files exist"

required_files=(
  "apps/sessions/forms.py"
  "apps/sessions/models.py"
  "apps/sessions/admin.py"
  "apps/sessions/factories.py"
  "apps/sessions/selectors.py"
  "apps/sessions/views.py"
  "apps/sessions/urls.py"
  "apps/sessions/tests/test_notes.py"
  "apps/sessions/tests/test_session_notes.py"
  "templates/sessions/session_detail.html"
  "templates/sessions/session_form.html"
  "templates/base.html"
  "docs/domain-model.md"
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

section "Verify StudyNote model fields and metadata"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from apps.sessions.models import StudyNote

field_names = {field.name for field in StudyNote._meta.fields}
expected_fields = {
    "id",
    "session",
    "content",
    "created_at",
}
missing_fields = expected_fields - field_names
index_names = {index.name for index in StudyNote._meta.indexes}

assert not missing_fields, f"Missing StudyNote fields: {sorted(missing_fields)}"
assert StudyNote._meta.app_label == "study_sessions"
assert StudyNote._meta.ordering == ["-created_at"]
assert "study_note_session_created_idx" in index_names

print("StudyNote fields verified")
print("Expected fields:", ", ".join(sorted(expected_fields)))
print("StudyNote app label verified:", StudyNote._meta.app_label)
print("StudyNote ordering verified:", StudyNote._meta.ordering)
print("StudyNote indexes verified:", ", ".join(sorted(index_names)))
PY

section "Verify StudyNote validation rules"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.validation").delete()

user = User.objects.create_user(
    email="sprint2.day4.validation.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=user,
    title="Sprint 2 Day 4 note validation session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

valid_note = StudyNote(
    session=session,
    content="This is a valid study note with useful content.",
)
valid_note.full_clean()
valid_note.save()

invalid_note = StudyNote(
    session=session,
    content="short",
)

try:
    invalid_note.full_clean()
except ValidationError as exc:
    assert "content" in exc.message_dict
    print("Short note content rejected")
else:
    raise AssertionError("Short note content was accepted")

assert valid_note.word_count > 0

print("Valid StudyNote saved")
print("StudyNote word count verified:", valid_note.word_count)
print("StudyNote validation rules verified")
PY

section "Verify note URL names resolve"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.urls import reverse

routes = {
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

assert routes["sessions:add_note"] == "/sessions/1/notes/new/"
assert routes["sessions:update_note"] == "/sessions/1/notes/2/edit/"
assert routes["sessions:delete_note"] == "/sessions/1/notes/2/delete/"

print("Note URL names verified")
PY

section "Verify StudyNoteForm fields and project styling"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from pathlib import Path

from apps.sessions.forms import StudyNoteForm

form = StudyNoteForm()
actual_fields = list(form.fields.keys())
content_widget = form.fields["content"].widget
content_attrs = content_widget.attrs
detail_template = Path("templates/sessions/session_detail.html").read_text(
    encoding="utf-8",
)

assert actual_fields == ["content"], actual_fields
assert content_attrs.get("rows") == 5
assert "Capture what you studied" in content_attrs.get("placeholder", "")

for token in [
    "form-ui",
    "btn-ui btn-ui-primary",
    "Note content",
    "sessions:add_note",
    "sessions:update_note",
    "sessions:delete_note",
]:
    assert token in detail_template, f"Missing project UI token: {token}"

assert "form-control" not in content_attrs.get("class", "")

print("StudyNoteForm fields verified")
print("StudyNoteForm content widget rows:", content_attrs.get("rows"))
print("Project form styling verified with form-ui and btn-ui tokens")
PY

section "Verify session detail renders note capture UI"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.detail").delete()

owner = User.objects.create_user(
    email="sprint2.day4.detail.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 detail note UI",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

client = Client()
client.force_login(owner)

response = client.get(reverse("sessions:detail", kwargs={"pk": session.pk}))
content = response.content.decode()

assert response.status_code == 200
assert "Add Note" in content
assert "Note content" in content
assert "form-ui" in content
assert reverse("sessions:add_note", kwargs={"pk": session.pk}) in content

print("Session detail renders note capture UI")
print("Detail status code:", response.status_code)
PY

section "Verify owned note creation workflow"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.create").delete()

owner = User.objects.create_user(
    email="sprint2.day4.create.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 note creation session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=50,
)

client = Client()
client.force_login(owner)

response = client.post(
    reverse("sessions:add_note", kwargs={"pk": session.pk}),
    {
        "content": (
            "Captured a useful note about forms, selectors, and ownership checks."
        ),
    },
)

created_note = StudyNote.objects.get(session=session)

assert response.status_code == 302
assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
assert "forms, selectors, and ownership" in created_note.content

print("Owned note creation workflow saves StudyNote")
print("Created note id:", created_note.pk)
PY

section "Verify new note appears on session detail"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.render").delete()

owner = User.objects.create_user(
    email="sprint2.day4.render.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 note rendering session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=55,
)

StudyNote.objects.create(
    session=session,
    content="Rendered note about relational modelling and persistence checks.",
)

client = Client()
client.force_login(owner)

response = client.get(reverse("sessions:detail", kwargs={"pk": session.pk}))
content = response.content.decode()

assert response.status_code == 200
assert "Rendered note about relational modelling" in content
assert "Added" in content
assert "words" in content

print("Study notes render on session detail")
print("Detail status code:", response.status_code)
PY

section "Verify short note submission is rejected"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.invalid").delete()

owner = User.objects.create_user(
    email="sprint2.day4.invalid.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 invalid note session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=35,
)

client = Client()
client.force_login(owner)

before_count = StudyNote.objects.filter(session=session).count()

response = client.post(
    reverse("sessions:add_note", kwargs={"pk": session.pk}),
    {
        "content": "short",
    },
)

after_count = StudyNote.objects.filter(session=session).count()

assert response.status_code == 400
assert before_count == after_count
assert "Study notes must contain at least 10 characters" in response.content.decode()

print("Short note submission rejected")
print("Note count unchanged:", after_count)
PY

section "Verify cross-user note creation returns 404"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.crosscreate").delete()

owner = User.objects.create_user(
    email="sprint2.day4.crosscreate.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day4.crosscreate.other@example.com",
    password="temporary-test-password",
)

foreign_session = StudySession.objects.create(
    owner=other_user,
    title="Sprint 2 Day 4 foreign note session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

client = Client()
client.force_login(owner)

response = client.post(
    reverse("sessions:add_note", kwargs={"pk": foreign_session.pk}),
    {
        "content": "This note must not attach to another user's session.",
    },
)

assert response.status_code == 404
assert StudyNote.objects.filter(session=foreign_session).count() == 0

print("Cross-user note creation returns 404")
print("Foreign session note count remains zero")
PY

section "Verify owned note update workflow"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.update").delete()

owner = User.objects.create_user(
    email="sprint2.day4.update.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 note update session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=65,
)

note = StudyNote.objects.create(
    session=session,
    content="Original note content that will be updated safely.",
)

client = Client()
client.force_login(owner)

response = client.post(
    reverse(
        "sessions:update_note",
        kwargs={"pk": session.pk, "note_pk": note.pk},
    ),
    {
        "content": (
            "Updated note content with a stronger explanation of the study outcome."
        ),
    },
)

note.refresh_from_db()

assert response.status_code == 302
assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
assert note.content == (
    "Updated note content with a stronger explanation of the study outcome."
)

print("Owned note update workflow saves changes")
print("Updated note id:", note.pk)
PY

section "Verify invalid note update is rejected"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.updateinvalid").delete()

owner = User.objects.create_user(
    email="sprint2.day4.updateinvalid.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 invalid note update session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

note = StudyNote.objects.create(
    session=session,
    content="Original valid content that should remain unchanged.",
)

client = Client()
client.force_login(owner)

response = client.post(
    reverse(
        "sessions:update_note",
        kwargs={"pk": session.pk, "note_pk": note.pk},
    ),
    {
        "content": "short",
    },
)

note.refresh_from_db()

assert response.status_code == 400
assert note.content == "Original valid content that should remain unchanged."
assert "Study notes must contain at least 10 characters" in response.content.decode()

print("Invalid note update rejected")
print("Note remains unchanged:", note.content)
PY

section "Verify owned note delete workflow"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.delete").delete()

owner = User.objects.create_user(
    email="sprint2.day4.delete.owner@example.com",
    password="temporary-test-password",
)

session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 note delete session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

note = StudyNote.objects.create(
    session=session,
    content="This note will be deleted through the owner-scoped workflow.",
)

client = Client()
client.force_login(owner)

response = client.post(
    reverse(
        "sessions:delete_note",
        kwargs={"pk": session.pk, "note_pk": note.pk},
    ),
)

assert response.status_code == 302
assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
assert not StudyNote.objects.filter(pk=note.pk).exists()

print("Owned note delete workflow removes StudyNote")
print("Deleted note id:", note.pk)
PY

section "Verify cross-user note update and delete return 404"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.crossnote").delete()

owner = User.objects.create_user(
    email="sprint2.day4.crossnote.owner@example.com",
    password="temporary-test-password",
)

other_user = User.objects.create_user(
    email="sprint2.day4.crossnote.other@example.com",
    password="temporary-test-password",
)

foreign_session = StudySession.objects.create(
    owner=other_user,
    title="Sprint 2 Day 4 foreign note management session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

foreign_note = StudyNote.objects.create(
    session=foreign_session,
    content="Foreign note content that must remain protected.",
)

client = Client()
client.force_login(owner)

update_response = client.post(
    reverse(
        "sessions:update_note",
        kwargs={"pk": foreign_session.pk, "note_pk": foreign_note.pk},
    ),
    {
        "content": "Attempted foreign note update should fail.",
    },
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
assert foreign_note.content == "Foreign note content that must remain protected."

print("Cross-user note update and delete return 404")
print("Foreign note remains unchanged")
PY

section "Verify wrong parent session note update returns 404"

run docker compose exec -T web python manage.py shell --settings=config.settings.local <<'PY'
from django.conf import settings
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession

settings.ALLOWED_HOSTS = [*settings.ALLOWED_HOSTS, "testserver"]

User = get_user_model()
User.objects.filter(email__startswith="sprint2.day4.wrongparent").delete()

owner = User.objects.create_user(
    email="sprint2.day4.wrongparent.owner@example.com",
    password="temporary-test-password",
)

note_session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 note parent session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

other_session = StudySession.objects.create(
    owner=owner,
    title="Sprint 2 Day 4 wrong route session",
    subject="Django",
    status=StudySession.Status.PLANNED,
    study_date=timezone.localdate(),
    duration_minutes=45,
)

note = StudyNote.objects.create(
    session=note_session,
    content="Original note content protected by parent session matching.",
)

client = Client()
client.force_login(owner)

response = client.post(
    reverse(
        "sessions:update_note",
        kwargs={"pk": other_session.pk, "note_pk": note.pk},
    ),
    {
        "content": "Attempted update through the wrong parent session.",
    },
)

note.refresh_from_db()

assert response.status_code == 404
assert note.content == "Original note content protected by parent session matching."

print("Wrong parent session note update returns 404")
print("Note remains attached to session id:", note_session.pk)
PY

section "Verify note documentation mentions ownership and validation"

run docker compose exec -T web python - <<'PY'
from pathlib import Path

content = Path("docs/domain-model.md").read_text(encoding="utf-8")

required_phrases = [
    "StudyNote",
    "parent session",
    "ownership",
    "at least 10 non-whitespace characters",
]

for phrase in required_phrases:
    assert phrase in content, f"Missing documentation phrase: {phrase}"
    print(f"Documentation phrase found: {phrase}")

print("Study note documentation verified")
PY

section "Run Sprint 2 Day 4 direct note tests"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions/tests/test_notes.py -q

section "Run Sprint 2 Day 4 note maintenance tests"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions/tests/test_session_notes.py -q

section "Run full Sprint 2 sessions test suite"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/sessions -q

section "Final receipt"

echo "Repository root verified."
echo "Sprint 2 Day 4 files verified."
echo "Docker/PostgreSQL stack started."
echo "Django system check passed."
echo "study_sessions migrations are clean and applied."
echo "StudyNote model fields and metadata verified."
echo "StudyNote validation rules verified."
echo "Note URL names verified."
echo "StudyNoteForm fields and project styling verified."
echo "Session detail renders note capture UI."
echo "Owned note creation workflow saves StudyNote."
echo "New notes appear on session detail."
echo "Short note submission is rejected."
echo "Cross-user note creation returns 404."
echo "Owned note update workflow saves changes."
echo "Invalid note update is rejected."
echo "Owned note delete workflow removes StudyNote."
echo "Cross-user note update and delete return 404."
echo "Wrong parent session note update returns 404."
echo "Study note documentation verified."
echo "Sprint 2 Day 4 direct note tests pass."
echo "Sprint 2 Day 4 note maintenance tests pass."
echo "apps/sessions test suite passes."
echo "Sprint 2 Day 4 verification complete."
