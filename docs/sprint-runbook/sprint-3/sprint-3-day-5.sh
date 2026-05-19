#!/usr/bin/env bash

# Sprint 3 Friday console-only verification runbook.
#
# Purpose:
#   Verify the final Sprint 3 insights dashboard workflow from the command line.
#   This script checks the current project files, Docker-backed Django runtime,
#   insights dashboard routing, owner-scoped data access, documentation, linting,
#   formatting, targeted insights tests, and the full regression suite.
#
# Execution:
#   chmod +x docs/sprint-runbook/sprint-3/sprint-3-day-5.sh
#   ./docs/sprint-runbook/sprint-3/sprint-3-day-5.sh
#
# Optional environment overrides:
#   PROJECT_ROOT=/path/to/project ./docs/sprint-runbook/sprint-3/sprint-3-day-5.sh
#   TEST_SETTINGS_MODULE=config.settings.test ./docs/sprint-runbook/sprint-3/sprint-3-day-5.sh
#   LOCAL_SETTINGS_MODULE=config.settings.local ./docs/sprint-runbook/sprint-3/sprint-3-day-5.sh

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/Users/adrianadewunmi/VSCODE/StudyBuddy-Study-Planner-Project}"
TEST_SETTINGS_MODULE="${TEST_SETTINGS_MODULE:-config.settings.test}"
LOCAL_SETTINGS_MODULE="${LOCAL_SETTINGS_MODULE:-config.settings.local}"
TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgres://studybuddy:studybuddy@db:5432/studybuddy_test}"

print_step() {
  printf "\n==> %s\n\n" "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@"
}

require_file() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    printf "MISSING: %s\n" "$file_path"
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

  printf "MISSING %s. Expected one of:\n" "$label"
  for file_path in "$@"; do
    printf "  - %s\n" "$file_path"
  done

  exit 1
}

require_phrase() {
  local phrase="$1"
  local file_path="$2"

  if ! grep -Fqi "$phrase" "$file_path"; then
    printf "MISSING PHRASE in %s: %s\n" "$file_path" "$phrase"
    exit 1
  fi

  printf "FOUND in %s: %s\n" "$file_path" "$phrase"
}

print_step "Verify repository root"
run cd "$PROJECT_ROOT"
printf "Repository root: %s\n" "$(pwd)"

print_step "Confirm Sprint 3 Day 5 files exist"

required_files=(
  "apps/insights/selectors.py"
  "apps/insights/views.py"
  "apps/insights/urls.py"
  "templates/insights/insight_list.html"
  "templates/base.html"
  "README.md"
  "docs/ai-nlp-contract.md"
  "docs/studybuddy-canonical-implementation-outline.md"
)

for file_path in "${required_files[@]}"; do
  require_file "$file_path"
done

require_one_of "insights dashboard test file" \
  "apps/insights/tests/test_insights_dashboard.py" \
  "apps/insights/tests/test_dashboard.py" \
  "apps/insights/tests/test_views.py"

print_step "Build and start Docker/PostgreSQL stack"
run docker compose up -d --build
run docker compose ps

print_step "Run Django system check"
run docker compose exec -T web python manage.py check --settings="$LOCAL_SETTINGS_MODULE"

print_step "Confirm project migrations remain clean"
run docker compose exec -T web python manage.py makemigrations --check --dry-run --settings="$LOCAL_SETTINGS_MODULE"

print_step "Apply database migrations"
run docker compose exec -T web python manage.py migrate --noinput --settings="$LOCAL_SETTINGS_MODULE"

print_step "Confirm insights dashboard modules import correctly"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.selectors import get_latest_session_insight, get_user_insights
from apps.insights.urls import urlpatterns
from apps.insights.views import GenerateInsightView, InsightListView

print("get_user_insights import verified")
print("get_latest_session_insight import verified")
print("InsightListView import verified")
print("GenerateInsightView import verified")
print("insights urlpatterns count:", len(urlpatterns))
print("Sprint 3 Day 5 insights dashboard import verification complete")
PY

print_step "Confirm insights dashboard URL is registered"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.urls import reverse

url = reverse("insights:list")

assert url == "/insights/", url

print("Insights dashboard URL:", url)
print("Insights dashboard URL registration verified")
PY

print_step "Confirm base navigation links to insights dashboard"

if ! grep -Fq "{% url 'insights:list' %}" templates/base.html; then
  printf "MISSING: insights dashboard navigation link in templates/base.html\n"
  exit 1
fi

printf "FOUND: insights dashboard navigation link in templates/base.html\n"

print_step "Confirm insights dashboard template contains current product sections"

required_template_phrases=(
  "Generated study insights"
  "summary"
  "keywords"
  "confidence"
  "explanation"
  "No insights yet"
  "Generate an insight from a study session."
  "Open Study Sessions"
)

for phrase in "${required_template_phrases[@]}"; do
  require_phrase "$phrase" "templates/insights/insight_list.html"
done

print_step "Verify insights selector scopes results through session ownership"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from uuid import uuid4

from apps.insights.selectors import get_user_insights
from apps.insights.services import generate_insight_for_session
from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.users.factories import UserFactory

suffix = uuid4().hex
viewer = UserFactory(
    email=f"runbook-viewer-{suffix}@example.com",
    username=f"runbook-viewer-{suffix[:20]}",
)
other_user = UserFactory(
    email=f"runbook-other-{suffix}@example.com",
    username=f"runbook-other-{suffix[:20]}",
)
own_session = StudySessionFactory(owner=viewer)
other_session = StudySessionFactory(owner=other_user)
viewer = own_session.owner

try:
    StudyNoteFactory(
        session=own_session,
        content="Django insights dashboard should show this user insight.",
    )
    StudyNoteFactory(
        session=other_session,
        content="Private insight owned by another user should stay hidden.",
    )

    own_result = generate_insight_for_session(
        session=own_session,
        requested_by=own_session.owner,
    )
    other_result = generate_insight_for_session(
        session=other_session,
        requested_by=other_session.owner,
    )

    own_insight = own_result.insight
    other_insight = other_result.insight

    insight_ids = list(get_user_insights(viewer).values_list("id", flat=True))

    assert own_insight.id in insight_ids, insight_ids
    assert other_insight.id not in insight_ids, insight_ids

    print("Visible insight IDs:", insight_ids)
    print("Own insight ID:", own_insight.id)
    print("Other insight ID:", other_insight.id)
    print("Session-owner scoped insight selector verified")
finally:
    viewer.delete()
    other_user.delete()
PY

print_step "Verify anonymous users are redirected from insights dashboard"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from django.test import Client
from django.urls import reverse

client = Client(HTTP_HOST="localhost")
response = client.get(reverse("insights:list"), HTTP_HOST="localhost")

assert response.status_code == 302, response.status_code
assert "login" in response["Location"], response["Location"]

print("Anonymous GET status:", response.status_code)
print("Anonymous redirect:", response["Location"])
print("Anonymous dashboard access redirect verified")
PY

print_step "Verify insights dashboard empty state"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from uuid import uuid4

from django.test import Client
from django.urls import reverse

from apps.users.factories import UserFactory

suffix = uuid4().hex
user = UserFactory(
    email=f"runbook-empty-{suffix}@example.com",
    username=f"runbook-empty-{suffix[:20]}",
)

try:
    client = Client(HTTP_HOST="localhost")
    client.force_login(user)

    response = client.get(reverse("insights:list"), HTTP_HOST="localhost")
    content = response.content.decode("utf-8")

    assert response.status_code == 200, response.status_code
    assert "No insights yet" in content, content[:500]
    assert "Generate an insight from a study session." in content, content[:500]
    assert "Open Study Sessions" in content, content[:500]

    print("Empty dashboard status:", response.status_code)
    print("Empty dashboard state verified")
finally:
    user.delete()
PY

print_step "Verify insights dashboard renders generated insight content"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from uuid import uuid4

from django.test import Client
from django.urls import reverse

from apps.insights.services import generate_insight_for_session
from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.users.factories import UserFactory

suffix = uuid4().hex
user = UserFactory(
    email=f"runbook-render-{suffix}@example.com",
    username=f"runbook-render-{suffix[:20]}",
)
session = StudySessionFactory(owner=user, title="Django Revision Session")

try:
    StudyNoteFactory(
        session=session,
        content=(
            "Django testing confirms dashboard insight rendering. "
            "Database-backed summaries and keywords remain available for review."
        ),
    )

    result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )
    insight = result.insight

    client = Client(HTTP_HOST="localhost")
    client.force_login(session.owner)

    response = client.get(reverse("insights:list"), HTTP_HOST="localhost")
    content = response.content.decode("utf-8")

    assert response.status_code == 200, response.status_code
    assert "Django Revision Session" in content, content[:1000]
    assert insight.summary in content, insight.summary
    assert f"{insight.confidence}%" in content, insight.confidence
    assert insight.explanation in content, insight.explanation

    for keyword in insight.keywords[:3]:
        assert keyword in content, keyword

    print("Insights dashboard status:", response.status_code)
    print("Rendered session title:", session.title)
    print("Rendered summary:", insight.summary)
    print("Rendered keywords:", insight.keywords)
    print("Rendered confidence:", insight.confidence)
    print("Rendered explanation verified")
finally:
    user.delete()
PY

print_step "Verify insights dashboard hides another user's insights"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from uuid import uuid4

from django.test import Client
from django.urls import reverse

from apps.insights.services import generate_insight_for_session
from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.users.factories import UserFactory

suffix = uuid4().hex
own_user = UserFactory(
    email=f"runbook-visible-{suffix}@example.com",
    username=f"runbook-visible-{suffix[:20]}",
)
other_user = UserFactory(
    email=f"runbook-hidden-{suffix}@example.com",
    username=f"runbook-hidden-{suffix[:20]}",
)
own_session = StudySessionFactory(owner=own_user, title="Visible Session")
other_session = StudySessionFactory(owner=other_user, title="Hidden Session")

try:
    StudyNoteFactory(
        session=own_session,
        content="Visible Django notes should appear on the insights dashboard.",
    )
    StudyNoteFactory(
        session=other_session,
        content="Hidden PostgreSQL notes should not appear for another user.",
    )

    own_result = generate_insight_for_session(
        session=own_session,
        requested_by=own_session.owner,
    )
    other_result = generate_insight_for_session(
        session=other_session,
        requested_by=other_session.owner,
    )

    own_insight = own_result.insight
    other_insight = other_result.insight

    client = Client(HTTP_HOST="localhost")
    client.force_login(own_session.owner)

    response = client.get(reverse("insights:list"), HTTP_HOST="localhost")
    content = response.content.decode("utf-8")

    assert response.status_code == 200, response.status_code
    assert own_session.title in content, content[:1000]
    assert own_insight.summary in content, own_insight.summary
    assert other_session.title not in content, content[:1000]
    assert other_insight.summary not in content, other_insight.summary

    print("Visible session title:", own_session.title)
    print("Hidden session title:", other_session.title)
    print("Cross-user dashboard visibility boundary verified")
finally:
    own_user.delete()
    other_user.delete()
PY

print_step "Verify insights dashboard pagination activates for many insights"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from uuid import uuid4

from django.test import Client
from django.urls import reverse

from apps.insights.services import generate_insight_for_session
from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.users.factories import UserFactory

suffix = uuid4().hex
user = UserFactory(
    email=f"runbook-pagination-{suffix}@example.com",
    username=f"runbook-pagination-{suffix[:20]}",
)

try:
    for number in range(13):
        session = StudySessionFactory(
            owner=user,
            title=f"Paginated Insight Session {number + 1}",
        )
        StudyNoteFactory(
            session=session,
            content=(
                f"Django pagination test note {number + 1}. "
                f"Pytest confirms insight dashboard pagination {number + 1}."
            ),
        )
        generate_insight_for_session(session=session, requested_by=user)

    client = Client(HTTP_HOST="localhost")
    client.force_login(user)

    response = client.get(reverse("insights:list"), HTTP_HOST="localhost")
    content = response.content.decode("utf-8")

    assert response.status_code == 200, response.status_code
    assert "Next" in content or "page=" in content, content[:1500]

    print("Paginated dashboard status:", response.status_code)
    print("Generated insight count for pagination:", 13)
    print("Insights dashboard pagination verified")
finally:
    user.delete()
PY

print_step "Verify README includes Sprint 3 AI/NLP feature summary"

required_readme_phrases=(
  "deterministic"
  "AI/NLP"
  "source hash"
  "keywords"
  "confidence"
  "explanation"
)

for phrase in "${required_readme_phrases[@]}"; do
  require_phrase "$phrase" "README.md"
done

print_step "Verify AI/NLP contract includes final Sprint 3 dashboard rules"

required_contract_phrases=(
  "stored in the database"
  "session detail"
  "insights dashboard"
  "A user can only view insights attached to their own sessions"
  "Cross-user access"
  "Testing Contract"
)

for phrase in "${required_contract_phrases[@]}"; do
  require_phrase "$phrase" "docs/ai-nlp-contract.md"
done

print_step "Verify canonical implementation outline exists and references Sprint 3"

required_canonical_phrases=(
  "central canonical implementation file"
  "Sprint 3: Deterministic AI/NLP Study Insights"
  "docs/ai-nlp-contract.md"
  "pytest apps/insights -q"
)

for phrase in "${required_canonical_phrases[@]}"; do
  require_phrase "$phrase" "docs/studybuddy-canonical-implementation-outline.md"
done

print_step "Run formatting and lint checks"
run docker compose exec -T web python -m black . --check
run docker compose exec -T web python -m ruff check .

print_step "Run Sprint 3 Day 5 insights dashboard tests"

dashboard_tests=()

if [[ -f "apps/insights/tests/test_insights_dashboard.py" ]]; then
  dashboard_tests+=("apps/insights/tests/test_insights_dashboard.py")
fi

if [[ -f "apps/insights/tests/test_dashboard.py" ]]; then
  dashboard_tests+=("apps/insights/tests/test_dashboard.py")
fi

if [[ -f "apps/insights/tests/test_views.py" ]]; then
  dashboard_tests+=("apps/insights/tests/test_views.py")
fi

run docker compose exec -T web env \
  DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" \
  TEST_DATABASE_URL="$TEST_DATABASE_URL" \
  pytest "${dashboard_tests[@]}" -q

print_step "Run all current insights tests"
run docker compose exec -T web env \
  DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" \
  TEST_DATABASE_URL="$TEST_DATABASE_URL" \
  pytest apps/insights -q

print_step "Run full project test suite"
run docker compose exec -T web env \
  DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" \
  TEST_DATABASE_URL="$TEST_DATABASE_URL" \
  pytest -q

print_step "Run final Django system check"
run docker compose exec -T web python manage.py check --settings="$LOCAL_SETTINGS_MODULE"

print_step "Final receipt"

cat <<'RECEIPT'
Repository root verified.
Sprint 3 Day 5 files verified.
Docker/PostgreSQL stack is running.
Django system check passed.
Project migrations are clean and applied.
Insights dashboard modules import correctly.
Insights dashboard URL is registered.
Base navigation links to insights dashboard.
Insights dashboard template contains current product sections.
User-scoped insight selector verified through session ownership.
Anonymous users are redirected from insights dashboard.
Empty insights dashboard state verified.
Generated insight content renders on insights dashboard.
Dashboard hides another user's insights.
Insights dashboard pagination verified.
README AI/NLP feature summary verified.
AI/NLP contract final dashboard rules verified.
Canonical implementation outline verified.
Black formatting check passed.
Ruff lint check passed.
Sprint 3 Day 5 insights dashboard tests pass.
Current insights tests pass.
Full project regression suite passes.
Final Django system check passed.
Sprint 3 Day 5 verification complete.
RECEIPT
