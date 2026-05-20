#!/usr/bin/env bash

# Sprint 4 Day 2 runbook: verify the current CI quality gate documentation and
# Docker-backed local verification flow.
#
# Execution:
#   chmod +x docs/sprint-runbook/sprint-4/sprint-4-day-2.sh
#   ./docs/sprint-runbook/sprint-4/sprint-4-day-2.sh
#
# Notes:
#   - This script builds and starts the Docker Compose stack.
#   - It runs the full local test suite through the Makefile.
#   - It validates the hosted GitHub Actions workflow by inspecting the current
#     repository files, not by calling GitHub.

set -euo pipefail

PROJECT_DIR="/Users/adrianadewunmi/VSCODE/StudyBuddy-Study-Planner-Project"

print_step() {
  printf '\n==> %s\n\n' "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@"
}

assert_file_exists() {
  local file_path="$1"

  if test -f "$file_path"; then
    printf 'FOUND: %s\n' "$file_path"
  else
    printf 'MISSING: %s\n' "$file_path"
    exit 1
  fi
}

assert_output_contains() {
  local output="$1"
  local expected="$2"
  local label="$3"

  if printf '%s\n' "$output" | grep -Fq "$expected"; then
    printf 'FOUND %s: %s\n' "$label" "$expected"
  else
    printf 'MISSING %s: %s\n' "$label" "$expected"
    printf '\nActual output was:\n%s\n' "$output"
    exit 1
  fi
}

print_step "Verify repository root"

run cd "$PROJECT_DIR"
printf 'Repository root: %s\n' "$(pwd)"

if test "$(basename "$(pwd)")" = "StudyBuddy-Study-Planner-Project"; then
  printf 'FOUND repository root: StudyBuddy-Study-Planner-Project\n'
else
  printf 'Repository root check failed.\n'
  exit 1
fi

print_step "Confirm Sprint 4 Day 2 CI and quality gate files exist"

assert_file_exists ".github/workflows/ci.yml"
assert_file_exists "README.md"
assert_file_exists "docs/ci.md"
assert_file_exists "docs/local-setup.md"
assert_file_exists "pyproject.toml"
assert_file_exists "pytest.ini"
assert_file_exists ".env.example"
assert_file_exists "requirements.txt"
assert_file_exists "Makefile"
assert_file_exists "Dockerfile"
assert_file_exists "docker-compose.yml"

print_step "Confirm GitHub Actions workflow contains expected trigger configuration"

ci_workflow="$(cat .github/workflows/ci.yml)"

assert_output_contains "$ci_workflow" "name: CI" "workflow name"
assert_output_contains "$ci_workflow" "push:" "push trigger"
assert_output_contains "$ci_workflow" "pull_request:" "pull request trigger"
assert_output_contains "$ci_workflow" "branches:" "branch filter"
assert_output_contains "$ci_workflow" "main" "main branch target"

print_step "Confirm GitHub Actions workflow provisions PostgreSQL"

assert_output_contains "$ci_workflow" "postgres:" "PostgreSQL service"
assert_output_contains "$ci_workflow" "postgres:16-alpine" "PostgreSQL image"
assert_output_contains "$ci_workflow" "POSTGRES_DB: studybuddy_test" "PostgreSQL database"
assert_output_contains "$ci_workflow" "POSTGRES_USER: studybuddy" "PostgreSQL user"
assert_output_contains "$ci_workflow" "POSTGRES_PASSWORD: studybuddy" "PostgreSQL password"
assert_output_contains "$ci_workflow" "pg_isready" "PostgreSQL health check"

print_step "Confirm GitHub Actions workflow installs and verifies the Django project"

assert_output_contains "$ci_workflow" "actions/checkout@v4" "checkout action"
assert_output_contains "$ci_workflow" "actions/setup-python@v5" "Python setup action"
assert_output_contains "$ci_workflow" 'python-version: "3.13"' "Python version"
assert_output_contains "$ci_workflow" "python -m pip install -r requirements.txt" "dependency installation"
assert_output_contains "$ci_workflow" "python manage.py check" "Django system check"
assert_output_contains "$ci_workflow" "python manage.py makemigrations --check --dry-run" "migration drift check"
assert_output_contains "$ci_workflow" "python manage.py migrate --noinput" "migration apply command"
assert_output_contains "$ci_workflow" "python -m ruff check ." "Ruff check"
assert_output_contains "$ci_workflow" "python -m black . --check" "Black format check"
assert_output_contains "$ci_workflow" "python -m isort . --check-only" "isort import order check"
assert_output_contains "$ci_workflow" "docker build -t studybuddy-ci ." "Docker image build"
assert_output_contains "$ci_workflow" "python -m pytest --cov=apps --cov=config --cov-report=xml -q" "pytest coverage command"

print_step "Confirm CI environment variables and Codecov upload are present"

assert_output_contains "$ci_workflow" "DJANGO_SETTINGS_MODULE: config.settings.test" "Django test settings"
assert_output_contains "$ci_workflow" "DJANGO_SECRET_KEY: ci-secret-key" "Django secret variable"
assert_output_contains "$ci_workflow" 'DJANGO_DEBUG: "False"' "Django debug setting"
assert_output_contains "$ci_workflow" "DJANGO_ALLOWED_HOSTS: localhost,127.0.0.1" "allowed hosts"
assert_output_contains "$ci_workflow" "DATABASE_URL: postgres://studybuddy:studybuddy@localhost:5432/studybuddy_test" "database URL"
assert_output_contains "$ci_workflow" "codecov/codecov-action@v5" "Codecov action"
assert_output_contains "$ci_workflow" "CODECOV_TOKEN" "Codecov token"
assert_output_contains "$ci_workflow" "fail_ci_if_error: true" "Codecov failure gate"

print_step "Confirm tool configuration files match the current project layout"

pyproject_contents="$(cat pyproject.toml)"
pytest_contents="$(cat pytest.ini)"

assert_output_contains "$pyproject_contents" "[tool.black]" "Black configuration"
assert_output_contains "$pyproject_contents" "[tool.ruff]" "Ruff configuration"
assert_output_contains "$pyproject_contents" "[tool.ruff.lint]" "Ruff lint configuration"
assert_output_contains "$pyproject_contents" "[tool.isort]" "isort configuration"
assert_output_contains "$pytest_contents" "[pytest]" "pytest configuration"
assert_output_contains "$pytest_contents" "DJANGO_SETTINGS_MODULE = config.settings.test" "pytest Django settings"
assert_output_contains "$pytest_contents" "python_files = tests.py test_*.py *_tests.py" "pytest test discovery"

print_step "Confirm CI documentation describes the quality gate"

ci_docs="$(cat docs/ci.md)"

assert_output_contains "$ci_docs" "Continuous Integration" "CI documentation title"
assert_output_contains "$ci_docs" "GitHub Actions" "GitHub Actions documentation"
assert_output_contains "$ci_docs" "Python 3.13" "Python documentation"
assert_output_contains "$ci_docs" "PostgreSQL 16 Alpine" "PostgreSQL documentation"
assert_output_contains "$ci_docs" "python -m ruff check ." "Ruff documentation"
assert_output_contains "$ci_docs" "python -m black . --check" "Black documentation"
assert_output_contains "$ci_docs" "python -m isort . --check-only" "isort documentation"
assert_output_contains "$ci_docs" "python -m pytest --cov=apps --cov=config --cov-report=xml -q" "pytest coverage documentation"
assert_output_contains "$ci_docs" "CODECOV_TOKEN" "Codecov documentation"
assert_output_contains "$ci_docs" "make ci" "local CI documentation"

print_step "Confirm local setup documentation reflects hosted and local checks"

local_setup_docs="$(cat docs/local-setup.md)"

assert_output_contains "$local_setup_docs" "make format-check" "format command documentation"
assert_output_contains "$local_setup_docs" "make lint" "lint command documentation"
assert_output_contains "$local_setup_docs" "make test" "test command documentation"
assert_output_contains "$local_setup_docs" 'runs `isort` directly' "hosted isort note"

print_step "Confirm README references the CI pipeline"

readme_contents="$(cat README.md)"

assert_output_contains "$readme_contents" "CI" "README CI reference"
assert_output_contains "$readme_contents" "GitHub Actions CI" "README GitHub Actions reference"
assert_output_contains "$readme_contents" "Codecov" "README Codecov reference"

print_step "Confirm Makefile exposes the current local CI quality gate"

make_ci_plan="$(make -n ci)"

printf '%s\n' "$make_ci_plan"

assert_output_contains "$make_ci_plan" "docker compose exec -T web" "Makefile Docker exec"
assert_output_contains "$make_ci_plan" "python -m black . --check" "Makefile Black check"
assert_output_contains "$make_ci_plan" "python -m ruff check ." "Makefile Ruff check"
assert_output_contains "$make_ci_plan" "python manage.py check --settings=config.settings.local" "Makefile Django check"
assert_output_contains "$make_ci_plan" "python manage.py makemigrations --check --dry-run --settings=config.settings.local" "Makefile migration drift check"
assert_output_contains "$make_ci_plan" "python manage.py migrate --noinput --settings=config.settings.local" "Makefile migrate command"
assert_output_contains "$make_ci_plan" "DJANGO_SETTINGS_MODULE=config.settings.test" "Makefile test settings"
assert_output_contains "$make_ci_plan" "TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test" "Makefile test database URL"
assert_output_contains "$make_ci_plan" "pytest -q" "Makefile pytest command"

print_step "Build and start Docker/PostgreSQL stack for local CI verification"

run make build
run make up

print_step "Confirm containers are running"

compose_ps="$(docker compose ps)"

printf '%s\n' "$compose_ps"

assert_output_contains "$compose_ps" "db" "compose status db"
assert_output_contains "$compose_ps" "web" "compose status web"

print_step "Run Black formatting check"

format_output="$(make format-check 2>&1)"

printf '%s\n' "$format_output"

assert_output_contains "$format_output" "left unchanged" "Black format receipt"

print_step "Run Ruff lint check"

lint_output="$(make lint 2>&1)"

printf '%s\n' "$lint_output"

assert_output_contains "$lint_output" "All checks passed" "Ruff lint receipt"

print_step "Run Django system check"

check_output="$(make check 2>&1)"

printf '%s\n' "$check_output"

assert_output_contains "$check_output" "System check identified no issues" "Django check receipt"

print_step "Confirm migration files are up to date"

migration_check_output="$(make check-migrations 2>&1)"

printf '%s\n' "$migration_check_output"

assert_output_contains "$migration_check_output" "No changes detected" "migration drift receipt"

print_step "Apply database migrations"

migrate_output="$(make migrate 2>&1)"

printf '%s\n' "$migrate_output"

assert_output_contains "$migrate_output" "Operations to perform:" "migration command receipt"

print_step "Run full project test suite"

test_output="$(make test 2>&1)"

printf '%s\n' "$test_output"

assert_output_contains "$test_output" "passed" "pytest receipt"

print_step "Run complete local CI quality gate through Makefile"

ci_output="$(make ci 2>&1)"

printf '%s\n' "$ci_output"

assert_output_contains "$ci_output" "All checks passed" "Ruff receipt from make ci"
assert_output_contains "$ci_output" "System check identified no issues" "Django check receipt from make ci"
assert_output_contains "$ci_output" "No changes detected" "migration drift receipt from make ci"
assert_output_contains "$ci_output" "passed" "pytest receipt from make ci"

print_step "Confirm working tree status for review"

git_status_output="$(git status --short)"

if test -z "$git_status_output"; then
  printf 'Working tree clean.\n'
else
  printf 'Working tree has changes:\n%s\n' "$git_status_output"
fi

print_step "Optional GitHub Actions visibility check"

if command -v gh >/dev/null 2>&1; then
  gh_run_output="$(gh run list --limit 5 2>&1 || true)"
  printf '%s\n' "$gh_run_output"

  if printf '%s\n' "$gh_run_output" | grep -Eiq "completed|queued|in_progress|success|failure"; then
    printf 'FOUND GitHub Actions run history from gh CLI.\n'
  else
    printf 'GitHub Actions run history not available from gh CLI in this shell.\n'
  fi
else
  printf 'gh CLI not installed or not available. Skipping remote workflow history check.\n'
fi

print_step "Review web logs for startup errors"

web_logs="$(docker compose logs --tail=80 web)"

printf '%s\n' "$web_logs"

if printf '%s\n' "$web_logs" | grep -Fq "Traceback"; then
  printf 'TRACEBACK found in web logs.\n'
  exit 1
else
  printf 'NO TRACEBACK in web logs\n'
fi

print_step "Final receipt"

printf '%s\n' "Repository root verified."
printf '%s\n' "Sprint 4 Day 2 CI files verified."
printf '%s\n' "GitHub Actions workflow includes push and pull request triggers."
printf '%s\n' "GitHub Actions workflow provisions PostgreSQL."
printf '%s\n' "GitHub Actions workflow installs dependencies."
printf '%s\n' "GitHub Actions workflow runs Django system check."
printf '%s\n' "GitHub Actions workflow checks migration drift."
printf '%s\n' "GitHub Actions workflow applies migrations."
printf '%s\n' "GitHub Actions workflow runs Ruff."
printf '%s\n' "GitHub Actions workflow runs Black check."
printf '%s\n' "GitHub Actions workflow runs isort check."
printf '%s\n' "GitHub Actions workflow builds the Docker image."
printf '%s\n' "GitHub Actions workflow runs pytest with coverage."
printf '%s\n' "GitHub Actions workflow uploads coverage to Codecov."
printf '%s\n' "pyproject.toml contains Black, Ruff, and isort configuration."
printf '%s\n' "pytest.ini contains pytest and Django test configuration."
printf '%s\n' "docs/ci.md documents the CI quality gate."
printf '%s\n' "docs/local-setup.md documents local and hosted check differences."
printf '%s\n' "README references CI."
printf '%s\n' "Makefile CI aliases expand to Docker-backed verification commands."
printf '%s\n' "Docker stack builds and starts."
printf '%s\n' "Black formatting check passes."
printf '%s\n' "Ruff lint check passes."
printf '%s\n' "Django system check passes."
printf '%s\n' "Migration drift check reports no changes."
printf '%s\n' "Database migrations apply."
printf '%s\n' "Full project test suite passes."
printf '%s\n' "Complete local CI quality gate passes through make ci."
printf '%s\n' "Web logs contain no traceback."
printf '%s\n' "Sprint 4 Day 2 CI and automated quality gate verification complete."
