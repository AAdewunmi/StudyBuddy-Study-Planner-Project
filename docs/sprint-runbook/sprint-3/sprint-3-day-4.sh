#!/usr/bin/env bash
#
# Sprint 3 Day 4 Console-Only Verification Runbook
#
# Purpose:
#   Verify the Thursday Sprint 3 insight workflow against the current
#   StudyBuddy project architecture:
#     - the insight service owns generation and idempotency
#     - selectors own user-scoped read queries
#     - the generate route is authenticated, POST-only, and owner-scoped
#     - session detail renders the latest generated insight
#     - views do not import deterministic NLP internals directly
#     - tests run against PostgreSQL through Docker Compose, not SQLite
#
# Execution instructions:
#   1. From anywhere inside the repository, run:
#
#        chmod +x docs/sprint-runbook/sprint-3/sprint-3-day-4.sh
#        ./docs/sprint-runbook/sprint-3/sprint-3-day-4.sh
#
#   2. Docker Desktop or a compatible Docker daemon must be running.
#
#   3. Optional overrides:
#
#        PROJECT_ROOT=/path/to/StudyBuddy-Study-Planner-Project \
#        LOCAL_SETTINGS_MODULE=config.settings.local \
#        TEST_SETTINGS_MODULE=config.settings.test \
#        DOCKER_TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test \
#        ./docs/sprint-runbook/sprint-3/sprint-3-day-4.sh
#
# Expected final receipt:
#   Repository root verified.
#   Sprint 3 Day 4 files verified.
#   Docker/PostgreSQL stack is running.
#   Django system check passed.
#   Project migrations are clean and applied.
#   Insight workflow modules import correctly.
#   Insight generation URL is registered.
#   StudyInsight session-owned model verified.
#   Session note text combination verified.
#   Insight generation persists NLP output.
#   Insight generation is idempotent for unchanged notes.
#   Changed notes create a new insight source hash.
#   Service blocks non-owner insight generation.
#   View allows owner insight generation.
#   View returns 404 for another user's session.
#   View returns 405 for GET.
#   View redirects anonymous users to login.
#   Latest insight selector verified.
#   Session detail renders generated insight.
#   AI/NLP contract Thursday rules verified.
#   Sprint 3 Day 4 targeted tests pass.
#   Current insights tests pass.
#   Full project regression suite passes.
#   Sprint 3 Day 4 verification complete.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PROJECT_ROOT="${PROJECT_ROOT:-$DEFAULT_PROJECT_ROOT}"
TEST_SETTINGS_MODULE="${TEST_SETTINGS_MODULE:-config.settings.test}"
LOCAL_SETTINGS_MODULE="${LOCAL_SETTINGS_MODULE:-config.settings.local}"
DOCKER_TEST_DATABASE_URL="${DOCKER_TEST_DATABASE_URL:-postgres://studybuddy:studybuddy@db:5432/studybuddy_test}"

print_step() {
  printf "\n==> %s\n\n" "$1"
}

run() {
  printf '$'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

require_file() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    printf "MISSING: %s\n" "$file_path" >&2
    exit 1
  fi

  printf "FOUND: %s\n" "$file_path"
}

require_one_of() {
  local label="$1"
  shift

  for file_path in "$@"; do
    if [[ -f "$file_path" ]]; then
      printf "FOUND %s: %s\n" "$label" "$file_path"
      return 0
    fi
  done

  printf "MISSING %s. Expected one of:\n" "$label" >&2
  for file_path in "$@"; do
    printf "  - %s\n" "$file_path" >&2
  done

  exit 1
}

require_phrase() {
  local phrase="$1"
  local file_path="$2"

  if ! grep -Fqi -- "$phrase" "$file_path"; then
    printf "MISSING CONTRACT PHRASE: %s\n" "$phrase" >&2
    exit 1
  fi

  printf "FOUND: %s\n" "$phrase"
}

forbid_phrase() {
  local phrase="$1"
  local file_path="$2"

  if grep -Fqi -- "$phrase" "$file_path"; then
    printf "STALE CONTRACT PHRASE PRESENT: %s\n" "$phrase" >&2
    exit 1
  fi

  printf "ABSENT: %s\n" "$phrase"
}

print_step "Verify repository root"
run cd "$PROJECT_ROOT"

if [[ ! -f "manage.py" ]]; then
  printf "MISSING: manage.py. PROJECT_ROOT is not the repository root: %s\n" "$PROJECT_ROOT" >&2
  exit 1
fi

printf "Repository root: %s\n" "$(pwd)"

print_step "Confirm Sprint 3 Day 4 files exist"

required_files=(
  "apps/insights/services.py"
  "apps/insights/selectors.py"
  "apps/insights/views.py"
  "apps/insights/urls.py"
  "apps/insights/tests/test_architecture_boundaries.py"
  "apps/sessions/selectors.py"
  "apps/sessions/views.py"
  "apps/sessions/urls.py"
  "apps/sessions/tests/test_architecture_boundaries.py"
  "apps/sessions/tests/test_views.py"
  "templates/sessions/session_detail.html"
  "config/urls.py"
  "docs/ai-nlp-contract.md"
)

for file_path in "${required_files[@]}"; do
  require_file "$file_path"
done

require_one_of "insight generation test file" \
  "apps/insights/tests/test_insight_generation.py" \
  "apps/insights/tests/test_services.py"

require_one_of "insight permission test file" \
  "apps/insights/tests/test_insight_permissions.py" \
  "apps/insights/tests/test_permissions.py"

print_step "Build and start Docker/PostgreSQL stack"
run docker compose up -d --build
run docker compose ps

print_step "Run Django system check"
run docker compose exec -T web python manage.py check --settings="$LOCAL_SETTINGS_MODULE"

print_step "Confirm project migrations remain clean"
run docker compose exec -T web python manage.py makemigrations --check --dry-run --settings="$LOCAL_SETTINGS_MODULE"

print_step "Apply database migrations"
run docker compose exec -T web python manage.py migrate --noinput --settings="$LOCAL_SETTINGS_MODULE"

print_step "Confirm insight workflow modules import correctly"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.selectors import get_latest_session_insight, get_user_insights
from apps.insights.services import generate_insight_for_session
from apps.insights.urls import urlpatterns
from apps.insights.views import GenerateInsightView
from apps.sessions.selectors import get_session_for_user_or_404, get_sessions_for_user
from apps.sessions.views import StudySessionDetailView, session_detail_context

print("generate_insight_for_session import verified")
print("get_latest_session_insight import verified")
print("get_user_insights import verified")
print("GenerateInsightView import verified")
print("get_sessions_for_user import verified")
print("get_session_for_user_or_404 import verified")
print("StudySessionDetailView import verified")
print("session_detail_context import verified")
print("insights urlpatterns count:", len(urlpatterns))
print("Sprint 3 Day 4 insight workflow import verification complete")
PY

print_step "Confirm insight generation URL is registered"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.urls import reverse

url = reverse("insights:generate", kwargs={"session_id": 1})

assert url == "/insights/sessions/1/generate/", url

print("Insight generation URL:", url)
print("Insight generation URL registration verified")
PY

print_step "Confirm StudyInsight remains session-owned"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.models import StudyInsight

fields = sorted(field.name for field in StudyInsight._meta.fields)
constraint_names = [constraint.name for constraint in StudyInsight._meta.constraints]

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

assert fields == expected_fields, fields
assert "owner" not in fields, fields
assert constraint_names == ["unique_insight_per_session_source"], constraint_names

print("StudyInsight fields:", fields)
print("StudyInsight constraints:", constraint_names)
print("StudyInsight session-owned model verified")
PY

print_step "Verify service combines session notes in deterministic order"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from uuid import uuid4

from apps.insights.services import get_session_note_text
from apps.sessions.models import StudyNote, StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-notes-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook deterministic note order",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(session=session, content="First note about Django forms.")
    StudyNote.objects.create(
        session=session,
        content="Second note about pytest coverage.",
    )

    result = get_session_note_text(session)

    assert "First note about Django forms." in result, result
    assert "Second note about pytest coverage." in result, result
    assert result.index("First note") < result.index("Second note"), result

    print("Combined note text:", result)
    print("Deterministic note combination verified")
finally:
    user.delete()
PY

print_step "Verify insight generation persists NLP output"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from uuid import uuid4

from apps.insights.models import StudyInsight
from apps.insights.services import generate_insight_for_session
from apps.sessions.models import StudyNote, StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-persist-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook insight persistence",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(
        session=session,
        content=(
            "Django testing improves confidence. "
            "Django views, forms, and database tests protect the workflow."
        ),
    )

    before_count = StudyInsight.objects.filter(session=session).count()

    result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    insight = result.insight
    after_count = StudyInsight.objects.filter(session=session).count()

    assert result.created is True, result.created
    assert after_count == before_count + 1, (before_count, after_count)
    assert insight.session == session, insight.session
    assert insight.summary, "Expected generated summary"
    assert insight.keywords, "Expected generated keywords"
    assert "django" in insight.keywords, insight.keywords
    assert 0 <= insight.confidence <= 100, insight.confidence
    assert insight.explanation, "Expected generated explanation"
    assert len(insight.source_hash) == 64, insight.source_hash

    print("Generated insight ID:", insight.pk)
    print("Generated summary:", insight.summary)
    print("Generated keywords:", insight.keywords)
    print("Generated confidence:", insight.confidence)
    print("Generated source hash:", insight.source_hash)
    print("Insight persistence verified")
finally:
    user.delete()
PY

print_step "Verify insight generation is idempotent for unchanged notes"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from uuid import uuid4

from apps.insights.models import StudyInsight
from apps.insights.services import generate_insight_for_session
from apps.sessions.models import StudyNote, StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-idempotent-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook unchanged notes",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(
        session=session,
        content="Testing testing database workflow for deterministic insights.",
    )

    first_result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )
    second_result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    assert first_result.insight.pk == second_result.insight.pk, (
        first_result.insight.pk,
        second_result.insight.pk,
    )
    assert StudyInsight.objects.filter(session=session).count() == 1
    assert first_result.created is True, first_result.created
    assert second_result.created is False, second_result.created

    print("First insight ID:", first_result.insight.pk)
    print("Second insight ID:", second_result.insight.pk)
    print("First created flag:", first_result.created)
    print("Second created flag:", second_result.created)
    print("Idempotent insight generation verified")
finally:
    user.delete()
PY

print_step "Verify changed notes create a new insight source hash"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from uuid import uuid4

from apps.insights.models import StudyInsight
from apps.insights.services import generate_insight_for_session
from apps.sessions.models import StudyNote, StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-changed-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook changed notes",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(session=session, content="Initial Django session notes.")

    first_result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    StudyNote.objects.create(
        session=session,
        content="Additional pytest and PostgreSQL testing notes.",
    )

    second_result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    assert first_result.insight.pk != second_result.insight.pk, (
        first_result.insight.pk,
        second_result.insight.pk,
    )
    assert first_result.insight.source_hash != second_result.insight.source_hash, (
        first_result.insight.source_hash,
        second_result.insight.source_hash,
    )
    assert StudyInsight.objects.filter(session=session).count() == 2

    print("First source hash:", first_result.insight.source_hash)
    print("Second source hash:", second_result.insight.source_hash)
    print("Changed-note insight regeneration verified")
finally:
    user.delete()
PY

print_step "Verify service rejects another user's session"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from uuid import uuid4

from apps.insights.models import StudyInsight
from apps.insights.services import generate_insight_for_session
from apps.sessions.models import StudyNote, StudySession

User = get_user_model()
owner = User.objects.create_user(
    email=f"runbook-day4-owner-{uuid4().hex}@example.com",
    password="password123",
)
other_user = User.objects.create_user(
    email=f"runbook-day4-other-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=owner,
    title="Runbook service permission",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(session=session, content="Private notes for the owner.")

    try:
        generate_insight_for_session(session=session, requested_by=other_user)
    except PermissionDenied:
        print("PermissionDenied raised for non-owner")
    else:
        raise AssertionError("Expected PermissionDenied for non-owner")

    assert StudyInsight.objects.filter(session=session).count() == 0

    print("Cross-user service permission enforcement verified")
finally:
    owner.delete()
    other_user.delete()
PY

print_step "Verify insight generation view allows the session owner"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from uuid import uuid4

from apps.insights.models import StudyInsight
from apps.sessions.models import StudyNote, StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-view-owner-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook owner view",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(
        session=session,
        content="Django views generate session insights.",
    )

    client = Client(HTTP_HOST="localhost")
    client.force_login(session.owner)

    response = client.post(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
        HTTP_HOST="localhost",
    )

    assert response.status_code == 302, response.status_code
    assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
    assert StudyInsight.objects.filter(session=session).exists()

    print("Owner POST status:", response.status_code)
    print("Owner redirect:", response["Location"])
    print("Owner insight count:", StudyInsight.objects.filter(session=session).count())
    print("Owner insight generation view verified")
finally:
    user.delete()
PY

print_step "Verify insight generation view returns 404 for another user's session"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from uuid import uuid4

from apps.insights.models import StudyInsight
from apps.sessions.models import StudyNote, StudySession

User = get_user_model()
owner = User.objects.create_user(
    email=f"runbook-day4-view-owner-{uuid4().hex}@example.com",
    password="password123",
)
other_user = User.objects.create_user(
    email=f"runbook-day4-view-other-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=owner,
    title="Runbook cross-user view",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(session=session, content="Private study notes.")

    client = Client(HTTP_HOST="localhost")
    client.force_login(other_user)

    response = client.post(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
        HTTP_HOST="localhost",
    )

    assert response.status_code == 404, response.status_code
    assert StudyInsight.objects.filter(session=session).count() == 0

    print("Non-owner POST status:", response.status_code)
    print("Non-owner insight count:", StudyInsight.objects.filter(session=session).count())
    print("Cross-user view permission enforcement verified")
finally:
    owner.delete()
    other_user.delete()
PY

print_step "Verify insight generation view returns 405 for GET"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from uuid import uuid4

from apps.sessions.models import StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-get-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook GET method",
    subject="Django",
    duration_minutes=45,
)

try:
    client = Client(HTTP_HOST="localhost")
    client.force_login(session.owner)

    response = client.get(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
        HTTP_HOST="localhost",
    )

    assert response.status_code == 405, response.status_code

    print("Owner GET status:", response.status_code)
    print("POST-only view behaviour verified")
finally:
    user.delete()
PY

print_step "Verify insight generation view redirects anonymous users"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from uuid import uuid4

from apps.sessions.models import StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-anon-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook anonymous access",
    subject="Django",
    duration_minutes=45,
)

try:
    client = Client(HTTP_HOST="localhost")
    response = client.post(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
        HTTP_HOST="localhost",
    )

    assert response.status_code == 302, response.status_code
    assert response["Location"].startswith(f"{reverse('users:login')}?next="), response["Location"]

    print("Anonymous POST status:", response.status_code)
    print("Anonymous redirect:", response["Location"])
    print("Anonymous access redirect verified")
finally:
    user.delete()
PY

print_step "Verify latest insight selector returns the latest user-owned insight"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from uuid import uuid4

from apps.insights.selectors import get_latest_session_insight
from apps.insights.services import generate_insight_for_session
from apps.sessions.models import StudyNote, StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-latest-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook latest selector",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(session=session, content="Initial Django notes.")

    first_result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    StudyNote.objects.create(session=session, content="Additional pytest notes.")

    second_result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    latest = get_latest_session_insight(
        session=session,
        user=session.owner,
    )

    assert latest.pk == second_result.insight.pk, (latest.pk, second_result.insight.pk)
    assert latest.pk != first_result.insight.pk, (latest.pk, first_result.insight.pk)

    print("First insight ID:", first_result.insight.pk)
    print("Second insight ID:", second_result.insight.pk)
    print("Latest selector insight ID:", latest.pk)
    print("Latest insight selector verified")
finally:
    user.delete()
PY

print_step "Verify session detail page renders generated insight"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.contrib.auth import get_user_model
from django.test import Client
from django.urls import reverse
from uuid import uuid4

from apps.insights.services import generate_insight_for_session
from apps.sessions.models import StudyNote, StudySession

user = get_user_model().objects.create_user(
    email=f"runbook-day4-detail-{uuid4().hex}@example.com",
    password="password123",
)
session = StudySession.objects.create(
    owner=user,
    title="Runbook session detail insight",
    subject="Django",
    duration_minutes=45,
)

try:
    StudyNote.objects.create(
        session=session,
        content=(
            "Django testing confirms session insight rendering. "
            "Database-backed persistence keeps generated summaries available."
        ),
    )

    result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )
    insight = result.insight

    client = Client(HTTP_HOST="localhost")
    client.force_login(session.owner)

    response = client.get(
        reverse("sessions:detail", kwargs={"pk": session.pk}),
        HTTP_HOST="localhost",
    )

    content = response.content.decode("utf-8")

    assert response.status_code == 200, response.status_code
    assert insight.summary in content, insight.summary
    assert f"{insight.confidence}%" in content, insight.confidence
    assert insight.explanation in content, insight.explanation
    assert reverse("insights:generate", kwargs={"session_id": session.pk}) in content

    for keyword in insight.keywords:
        assert keyword in content, keyword

    print("Session detail status:", response.status_code)
    print("Rendered insight summary:", insight.summary)
    print("Rendered confidence:", insight.confidence)
    print("Rendered keywords:", insight.keywords)
    print("Session detail insight rendering verified")
finally:
    user.delete()
PY

print_step "Confirm AI/NLP contract includes current Thursday rules"

required_phrases=(
  "source hash"
  "reuse the existing insight"
  "stored in the database"
  "A user should only generate insights for their own sessions"
  "Cross-user access should be blocked"
  "session detail"
)

for phrase in "${required_phrases[@]}"; do
  require_phrase "$phrase" "docs/ai-nlp-contract.md"
done

stale_phrases=(
  "still future integration work"
  "no end-to-end insight generation UI yet"
)

for phrase in "${stale_phrases[@]}"; do
  forbid_phrase "$phrase" "docs/ai-nlp-contract.md"
done

print_step "Run formatting and lint checks"
run docker compose exec -T web python -m black . --check
run docker compose exec -T web python -m ruff check .

print_step "Run Sprint 3 Day 4 targeted tests"

targeted_tests=(
  "apps/insights/tests/test_architecture_boundaries.py"
  "apps/insights/tests/test_insight_generation.py"
  "apps/insights/tests/test_insight_permissions.py"
  "apps/sessions/tests/test_architecture_boundaries.py"
  "apps/sessions/tests/test_views.py::test_session_detail_renders_latest_insight_panel"
)

run docker compose exec -T web env \
  DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" \
  TEST_DATABASE_URL="$DOCKER_TEST_DATABASE_URL" \
  pytest "${targeted_tests[@]}" -q

print_step "Run all current insights tests"
run docker compose exec -T web env \
  DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" \
  TEST_DATABASE_URL="$DOCKER_TEST_DATABASE_URL" \
  pytest apps/insights -q

print_step "Run full project test suite"
run docker compose exec -T web env \
  DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" \
  TEST_DATABASE_URL="$DOCKER_TEST_DATABASE_URL" \
  pytest -q

print_step "Final receipt"

cat <<'RECEIPT'
Repository root verified.
Sprint 3 Day 4 files verified.
Docker/PostgreSQL stack is running.
Django system check passed.
Project migrations are clean and applied.
Insight workflow modules import correctly.
Insight generation URL is registered.
StudyInsight session-owned model verified.
Session note text combination verified.
Insight generation persists NLP output.
Insight generation is idempotent for unchanged notes.
Changed notes create a new insight source hash.
Service blocks non-owner insight generation.
View allows owner insight generation.
View returns 404 for another user's session.
View returns 405 for GET.
View redirects anonymous users to login.
Latest insight selector verified.
Session detail renders generated insight.
AI/NLP contract Thursday rules verified.
Sprint 3 Day 4 targeted tests pass.
Current insights tests pass.
Full project regression suite passes.
Sprint 3 Day 4 verification complete.
RECEIPT
