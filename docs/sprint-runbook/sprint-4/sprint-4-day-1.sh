#!/usr/bin/env bash

# Sprint 4 Day 1 console-only verification runbook.
#
# Purpose:
#   Verify the current Docker-backed local development workflow for StudyBuddy.
#   This script proves that a reviewer can build the web image, start Django
#   and PostgreSQL with Docker Compose, apply migrations, run project checks,
#   execute the targeted insights suite, execute the full suite, and confirm
#   the MVP is served locally.
#
# Execution:
#   chmod +x docs/sprint-runbook/sprint-4/sprint-4-day-1.sh
#   ./docs/sprint-runbook/sprint-4/sprint-4-day-1.sh
#
# Optional environment overrides:
#   PROJECT_ROOT=/path/to/project ./docs/sprint-runbook/sprint-4/sprint-4-day-1.sh
#   LOCAL_SETTINGS_MODULE=config.settings.local ./docs/sprint-runbook/sprint-4/sprint-4-day-1.sh
#   TEST_SETTINGS_MODULE=config.settings.test ./docs/sprint-runbook/sprint-4/sprint-4-day-1.sh
#   TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test ./docs/sprint-runbook/sprint-4/sprint-4-day-1.sh
#
# Notes:
#   This runbook verifies both the served MVP home page at / and the deployment
#   health endpoint at /health/.

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/Users/adrianadewunmi/VSCODE/StudyBuddy-Study-Planner-Project}"
LOCAL_SETTINGS_MODULE="${LOCAL_SETTINGS_MODULE:-config.settings.local}"
TEST_SETTINGS_MODULE="${TEST_SETTINGS_MODULE:-config.settings.test}"
TEST_DATABASE_URL="${TEST_DATABASE_URL:-postgres://studybuddy:studybuddy@db:5432/studybuddy_test}"

print_step() {
  printf "\n==> %s\n\n" "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@"
}

capture() {
  printf '$ %s\n' "$*" >&2
  "$@" 2>&1
}

require_file() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    printf "MISSING: %s\n" "$file_path"
    exit 1
  fi

  printf "FOUND: %s\n" "$file_path"
}

require_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    printf "MISSING %s: %s\n" "$label" "$needle"
    exit 1
  fi

  printf "FOUND %s: %s\n" "$label" "$needle"
}

require_no_traceback() {
  local output="$1"
  local label="$2"

  if printf '%s\n' "$output" | grep -qi "traceback"; then
    printf "TRACEBACK FOUND in %s\n" "$label"
    exit 1
  fi

  printf "NO TRACEBACK in %s\n" "$label"
}

print_step "Verify repository root"
run cd "$PROJECT_ROOT"
repo_root="$(pwd)"
printf "Repository root: %s\n" "$repo_root"
require_contains "$repo_root" "StudyBuddy-Study-Planner-Project" "repository root"

print_step "Confirm Sprint 4 Day 1 workflow files exist"

required_files=(
  "Dockerfile"
  "docker-compose.yml"
  "Makefile"
  ".env.example"
  "requirements.txt"
  "README.md"
  "RUNBOOK.md"
  "docs/local-setup.md"
  "docs/sprint-runbook/sprint-4/sprint-4-day-1.sh"
)

for file_path in "${required_files[@]}"; do
  require_file "$file_path"
done

print_step "Confirm Docker Compose can parse the local service topology"
compose_services="$(capture docker compose config --services)"
printf '%s\n' "$compose_services"
require_contains "$compose_services" "db" "compose service"
require_contains "$compose_services" "web" "compose service"

print_step "Confirm Makefile exposes the current verification aliases"
make_dry_run="$(capture make -n ci)"
printf '%s\n' "$make_dry_run"
require_contains "$make_dry_run" "docker compose exec -T web" "Makefile Docker exec"
require_contains "$make_dry_run" "DJANGO_SETTINGS_MODULE=$TEST_SETTINGS_MODULE" "Makefile test settings"
require_contains "$make_dry_run" "TEST_DATABASE_URL=$TEST_DATABASE_URL" "Makefile test database URL"
require_contains "$make_dry_run" "python -m black . --check" "Makefile Black check"
require_contains "$make_dry_run" "python -m ruff check ." "Makefile Ruff check"
require_contains "$make_dry_run" "pytest -q" "Makefile pytest command"

print_step "Build and start Docker/PostgreSQL stack"
run make build
run make up

print_step "Confirm containers are running"
compose_status="$(capture docker compose ps)"
printf '%s\n' "$compose_status"
require_contains "$compose_status" "db" "compose status"
require_contains "$compose_status" "web" "compose status"

print_step "Run Django system check through Makefile"
check_output="$(capture make check)"
printf '%s\n' "$check_output"
require_contains "$check_output" "System check identified no issues" "Django check"

print_step "Apply database migrations through Makefile"
migrate_output="$(capture make migrate)"
printf '%s\n' "$migrate_output"
require_contains "$migrate_output" "Operations to perform:" "migration command"

print_step "Confirm model migrations remain clean"
makemigrations_output="$(capture make check-migrations)"
printf '%s\n' "$makemigrations_output"
require_contains "$makemigrations_output" "No changes detected" "migration drift check"

print_step "Run formatting and lint checks through Makefile"
format_output="$(capture make format-check)"
printf '%s\n' "$format_output"
require_contains "$format_output" "left unchanged" "Black format check"

lint_output="$(capture make lint)"
printf '%s\n' "$lint_output"
require_contains "$lint_output" "All checks passed" "Ruff lint check"

print_step "Run targeted Sprint 3 insights tests through Makefile"
insights_output="$(capture make test-insights)"
printf '%s\n' "$insights_output"
require_contains "$insights_output" "69 passed" "current insights test receipt"

print_step "Run full project test suite through Makefile"
full_test_output="$(capture make test)"
printf '%s\n' "$full_test_output"
require_contains "$full_test_output" "202 passed" "current full test receipt"

print_step "Confirm the local MVP responds over HTTP"
home_status="$(capture curl -fsS -o /dev/null -w "%{http_code}" http://localhost:8000/)"
printf "Home page HTTP status: %s\n" "$home_status"
require_contains "$home_status" "200" "home page HTTP status"

print_step "Confirm the health endpoint responds over HTTP"
health_response="$(capture curl -fsS http://localhost:8000/health/)"
printf '%s\n' "$health_response"
require_contains "$health_response" '"status": "ok"' "health endpoint status"
require_contains "$health_response" '"service": "studybuddy"' "health endpoint service"
require_contains "$health_response" '"database": "ok"' "health endpoint database check"

print_step "Review web logs for startup errors"
web_logs="$(capture docker compose logs --tail=80 web)"
printf '%s\n' "$web_logs"
require_no_traceback "$web_logs" "web logs"

print_step "Review database logs for readiness"
db_logs="$(capture docker compose logs --tail=80 db)"
printf '%s\n' "$db_logs"
require_contains "$db_logs" "ready to accept connections" "PostgreSQL readiness"
require_no_traceback "$db_logs" "database logs"

print_step "Final receipt"

cat <<'RECEIPT'
Repository root verified.
Sprint 4 Day 1 workflow files verified.
Docker Compose parses db and web services.
Makefile aliases expand to the current Docker verification workflow.
Docker image builds successfully.
Docker Compose starts PostgreSQL and Django services.
Django system check passes with local settings.
Database migrations apply with local settings.
Migration drift check reports no changes.
Black formatting check passes.
Ruff lint check passes.
Targeted insights tests pass: 69 passed.
Full project suite passes: 202 passed.
Local MVP home page returns HTTP 200.
Health endpoint returns ok service and database checks.
Web logs contain no traceback.
Database logs show PostgreSQL readiness.
Sprint 4 Day 1 Docker workflow verification complete.
RECEIPT
