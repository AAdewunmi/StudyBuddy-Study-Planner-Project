#!/usr/bin/env bash
#
# Sprint 4 Day 4 runbook: Render release verification.
#
# Usage:
#   chmod +x docs/sprint-runbook/sprint-4/sprint-4-day-4.sh
#   ./docs/sprint-runbook/sprint-4/sprint-4-day-4.sh
#
# If Render generated a different service URL:
#   LIVE_URL="https://your-render-service.onrender.com" \
#     ./docs/sprint-runbook/sprint-4/sprint-4-day-4.sh

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
LIVE_URL="${LIVE_URL:-https://studybuddy-django-app.onrender.com}"

PROD_ENV=(
  "DJANGO_SETTINGS_MODULE=config.settings.production"
  "DJANGO_SECRET_KEY=production-check-secret-key-for-local-verification-only"
  "DJANGO_DEBUG=False"
  "DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,web"
  "DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:8000,http://127.0.0.1:8000"
  "DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local"
  "DATABASE_SSL_REQUIRE=False"
  "DJANGO_SECURE_SSL_REDIRECT=True"
  "DJANGO_SECURE_HSTS_SECONDS=31536000"
  "DJANGO_DEFAULT_FROM_EMAIL=local-deploy-check@example.com"
  "DJANGO_EMAIL_HOST=localhost"
  "RELEASE_SHA=sprint-4-day-4-local"
)

TEST_ENV=(
  "DJANGO_SETTINGS_MODULE=config.settings.test"
  "TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test"
)

print_step() {
  printf '\n==> %s\n\n' "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@"
}

capture() {
  "$@" 2>&1
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

assert_output_matches() {
  local output="$1"
  local pattern="$2"
  local label="$3"

  if printf '%s\n' "$output" | grep -Eq "$pattern"; then
    printf 'FOUND %s matching pattern: %s\n' "$label" "$pattern"
  else
    printf 'MISSING %s matching pattern: %s\n' "$label" "$pattern"
    printf '\nActual output was:\n%s\n' "$output"
    exit 1
  fi
}

assert_http_status() {
  local url="$1"
  local expected_status="$2"
  local label="$3"
  local actual_status

  actual_status="$(curl -fsS -o /dev/null -w '%{http_code}' "$url" || true)"
  printf '%s HTTP status: %s\n' "$label" "$actual_status"

  if test "$actual_status" = "$expected_status"; then
    printf 'FOUND %s HTTP status: %s\n' "$label" "$expected_status"
  else
    printf 'Expected %s to return %s but got %s\n' \
      "$label" "$expected_status" "$actual_status"
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

print_step "Confirm Sprint 4 Day 4 deployment verification files exist"

assert_file_exists "config/settings/production.py"
assert_file_exists "config/settings/base.py"
assert_file_exists "config/urls.py"
assert_file_exists "tests/test_health_check.py"
assert_file_exists "docs/deployment.md"
assert_file_exists "docs/final-verification.md"
assert_file_exists "docs/ci.md"
assert_file_exists "README.md"
assert_file_exists ".env.example"
assert_file_exists "requirements.txt"
assert_file_exists "Dockerfile"
assert_file_exists "docker-compose.yml"
assert_file_exists "render.yaml"
assert_file_exists "Makefile"
assert_file_exists ".github/workflows/ci.yml"

print_step "Confirm deployment docs describe Render runtime and boundary"

deployment_docs="$(cat docs/deployment.md)"

assert_output_contains "$deployment_docs" "Why Render" "Render rationale"
assert_output_contains "$deployment_docs" "Platform Boundary" "platform boundary"
assert_output_contains "$deployment_docs" "render.yaml" "Render Blueprint"
assert_output_contains "$deployment_docs" "DJANGO_SETTINGS_MODULE=config.settings.production" "production settings"
assert_output_contains "$deployment_docs" "DJANGO_SECRET_KEY" "secret key"
assert_output_contains "$deployment_docs" "DJANGO_ALLOWED_HOSTS" "allowed hosts"
assert_output_contains "$deployment_docs" "DJANGO_CSRF_TRUSTED_ORIGINS" "CSRF origins"
assert_output_contains "$deployment_docs" "DATABASE_URL" "database URL"
assert_output_contains "$deployment_docs" "DJANGO_DEFAULT_FROM_EMAIL" "default sender email"
assert_output_contains "$deployment_docs" "DJANGO_EMAIL_HOST" "SMTP host"
assert_output_contains "$deployment_docs" "RENDER_GIT_COMMIT" "Render commit release metadata"
assert_output_contains "$deployment_docs" "collectstatic" "static collection"
assert_output_contains "$deployment_docs" "migrate" "migration command"
assert_output_contains "$deployment_docs" "gunicorn" "Gunicorn start command"
assert_output_contains "$deployment_docs" "/health/" "health check"

print_step "Confirm final verification docs describe live release checks"

final_verification_docs="$(cat docs/final-verification.md)"

assert_output_contains "$final_verification_docs" "Final Verification" "final verification title"
assert_output_contains "$final_verification_docs" "Live MVP URL" "live MVP URL"
assert_output_contains "$final_verification_docs" "Post-Deploy Verification" "post-deploy section"
assert_output_contains "$final_verification_docs" "/health/" "health verification"
assert_output_contains "$final_verification_docs" "pytest" "test verification"
assert_output_contains "$final_verification_docs" "check --deploy" "deploy check"
assert_output_contains "$final_verification_docs" "Sign up with a test email address" "signup smoke step"
assert_output_contains "$final_verification_docs" "Create a study session" "session smoke step"
assert_output_contains "$final_verification_docs" "Add a note" "note smoke step"
assert_output_contains "$final_verification_docs" "Generate an insight" "insight smoke step"

print_step "Confirm README references deployment, Render, and health checks"

readme_contents="$(cat README.md)"

assert_output_contains "$readme_contents" "studybuddy-django-app.onrender.com" "README live URL"
assert_output_contains "$readme_contents" "/health/" "README health endpoint"
assert_output_contains "$readme_contents" "Render" "README Render reference"
assert_output_contains "$readme_contents" "Deployment" "README deployment reference"
assert_output_contains "$readme_contents" "RENDER_GIT_COMMIT" "README release metadata"

print_step "Confirm production settings remain environment-driven"

production_settings="$(cat config/settings/production.py)"
base_settings="$(cat config/settings/base.py)"

assert_output_contains "$production_settings" "DEBUG = False" "production debug disabled"
assert_output_contains "$production_settings" "DJANGO_SECRET_KEY" "production secret"
assert_output_contains "$production_settings" "DJANGO_ALLOWED_HOSTS" "production allowed hosts"
assert_output_contains "$production_settings" "DJANGO_CSRF_TRUSTED_ORIGINS" "production CSRF origins"
assert_output_contains "$production_settings" "required_env(\"DATABASE_URL\")" "required database URL"
assert_output_contains "$production_settings" "DJANGO_DEFAULT_FROM_EMAIL" "production default sender"
assert_output_contains "$production_settings" "DJANGO_EMAIL_HOST" "production SMTP host"
assert_output_contains "$production_settings" "django.core.mail.backends.smtp.EmailBackend" "production SMTP email backend"
assert_output_contains "$production_settings" "SECURE_SSL_REDIRECT" "SSL redirect"
assert_output_contains "$production_settings" "SESSION_COOKIE_SECURE" "secure session cookie"
assert_output_contains "$production_settings" "CSRF_COOKIE_SECURE" "secure CSRF cookie"
assert_output_contains "$production_settings" "SECURE_HSTS_SECONDS" "HSTS"
assert_output_contains "$production_settings" "CompressedManifestStaticFilesStorage" "manifest storage"
assert_output_contains "$base_settings" "RENDER_GIT_COMMIT" "Render commit fallback"

print_step "Confirm canonical auth namespace is /users/"

urls_contents="$(cat config/urls.py)"

assert_output_contains "$urls_contents" 'path("users/", include("apps.users.urls"))' "users URL mount"
if printf '%s\n' "$urls_contents" | grep -Fq 'path("accounts/"'; then
  printf 'Unexpected /accounts/ URL mount found.\n'
  exit 1
else
  printf 'NO duplicate /accounts/ URL mount found.\n'
fi

print_step "Confirm .env.example documents production variables without real secrets"

env_example="$(cat .env.example)"

assert_output_contains "$env_example" "DJANGO_SETTINGS_MODULE=config.settings.production" "production settings example"
assert_output_contains "$env_example" "DJANGO_DEBUG=false" "production debug example"
assert_output_contains "$env_example" "DJANGO_ALLOWED_HOSTS" "allowed hosts example"
assert_output_contains "$env_example" "DJANGO_CSRF_TRUSTED_ORIGINS" "CSRF origins example"
assert_output_contains "$env_example" "DATABASE_URL" "database URL example"
assert_output_contains "$env_example" "DJANGO_DEFAULT_FROM_EMAIL" "default sender example"
assert_output_contains "$env_example" "DJANGO_EMAIL_HOST" "SMTP host example"
assert_output_contains "$env_example" "RENDER_GIT_COMMIT" "Render release metadata example"

if printf '%s\n' "$env_example" | grep -Eiq 'password=[^[:space:]]{12,}|secret=[^[:space:]]{20,}|sk-[A-Za-z0-9]'; then
  printf 'Potential committed secret found in .env.example.\n'
  exit 1
else
  printf 'NO committed production secret pattern found in .env.example\n'
fi

print_step "Confirm GitHub Actions workflow is present"

ci_workflow="$(cat .github/workflows/ci.yml)"

assert_output_contains "$ci_workflow" "name:" "workflow name"
assert_output_contains "$ci_workflow" "push:" "push trigger"
assert_output_contains "$ci_workflow" "pull_request:" "pull request trigger"
assert_output_contains "$ci_workflow" "postgres:16" "PostgreSQL service"
assert_output_contains "$ci_workflow" "python manage.py check" "Django check"
assert_output_contains "$ci_workflow" "python manage.py migrate" "migration command"
assert_output_contains "$ci_workflow" "python -m isort . --check-only" "isort check"
assert_output_contains "$ci_workflow" "docker build -t studybuddy-ci ." "Docker build"
assert_output_contains "$ci_workflow" "pytest" "pytest command"

print_step "Build and start Docker/PostgreSQL stack"

run make build
run make up

print_step "Confirm containers are running"

compose_ps="$(docker compose ps)"
printf '%s\n' "$compose_ps"

assert_output_contains "$compose_ps" "db" "compose db"
assert_output_contains "$compose_ps" "web" "compose web"
assert_output_contains "$compose_ps" "healthy" "compose database health"

print_step "Run local Django system check"

local_check_output="$(make check 2>&1)"
printf '%s\n' "$local_check_output"
assert_output_contains "$local_check_output" "System check identified no issues" "local Django check"

print_step "Apply local database migrations"

migrate_output="$(make migrate 2>&1)"
printf '%s\n' "$migrate_output"
assert_output_contains "$migrate_output" "Operations to perform:" "migration receipt"

print_step "Run full project test suite before deployment verification"

test_output="$(make test 2>&1)"
printf '%s\n' "$test_output"
assert_output_matches "$test_output" "[0-9]+ passed" "full pytest receipt"

print_step "Run production deployment checks"

deploy_check_output="$(
  docker compose exec -T web env "${PROD_ENV[@]}" \
    python manage.py check --deploy --settings=config.settings.production 2>&1
)"
printf '%s\n' "$deploy_check_output"
assert_output_contains "$deploy_check_output" "System check identified no issues" "production deploy check"

print_step "Run production static collection"

collectstatic_output="$(
  docker compose exec -T web env "${PROD_ENV[@]}" \
    python manage.py collectstatic --noinput --settings=config.settings.production 2>&1
)"
printf '%s\n' "$collectstatic_output"
assert_output_matches "$collectstatic_output" "static file|static files|post-processed|unmodified" "collectstatic"

print_step "Confirm collected static assets exist"

staticfiles_output="$(
  docker compose exec -T web sh -c 'test -d staticfiles && find staticfiles -type f | head -10'
)"
printf '%s\n' "$staticfiles_output"
assert_output_matches "$staticfiles_output" ".+" "collected static files"

print_step "Run focused health and auth URL tests"

focused_test_output="$(
  docker compose exec -T web env "${TEST_ENV[@]}" \
    pytest tests/test_health_check.py tests/test_views.py apps/users/tests/test_auth_views.py -q 2>&1
)"
printf '%s\n' "$focused_test_output"
assert_output_contains "$focused_test_output" "passed" "focused pytest receipt"

print_step "Verify local health endpoint before checking live Render"

local_health_output="$(curl -fsS -i http://localhost:8000/health/)"
printf '%s\n' "$local_health_output"

assert_output_contains "$local_health_output" "HTTP/1.1 200 OK" "local health HTTP 200"
assert_output_contains "$local_health_output" '"status": "ok"' "local health status"
assert_output_contains "$local_health_output" '"service": "studybuddy"' "local service"
assert_output_contains "$local_health_output" '"database": "ok"' "local database"

print_step "Confirm latest GitHub Actions runs succeeded when gh CLI is available"

if command -v gh >/dev/null 2>&1; then
  gh_run_output="$(gh run list --limit 5 2>&1 || true)"
  printf '%s\n' "$gh_run_output"

  if printf '%s\n' "$gh_run_output" | grep -Eiq "completed[[:space:]]+success"; then
    printf 'FOUND successful recent GitHub Actions run.\n'
  else
    printf 'No successful recent GitHub Actions run found from gh CLI output.\n'
    exit 1
  fi
else
  printf 'gh CLI not installed or not available. Skipping hosted CI history check.\n'
fi

print_step "Confirm current Git branch and commit for release traceability"

current_branch="$(git branch --show-current)"
current_commit="$(git rev-parse --short HEAD)"

printf 'Current branch: %s\n' "$current_branch"
printf 'Current commit: %s\n' "$current_commit"

if test -n "$current_commit"; then
  printf 'FOUND current commit for release traceability: %s\n' "$current_commit"
else
  printf 'Current commit could not be resolved.\n'
  exit 1
fi

print_step "Confirm remote origin points to StudyBuddy repository"

remote_origin="$(git remote get-url origin 2>/dev/null || true)"
printf 'Remote origin: %s\n' "$remote_origin"
assert_output_matches "$remote_origin" "[sS]tudy[bB]uddy" "StudyBuddy remote origin"

print_step "Check working tree status before live release verification"

git_status_output="$(git status --short)"

if test -z "$git_status_output"; then
  printf 'Working tree clean.\n'
else
  printf 'Working tree has changes:\n%s\n' "$git_status_output"
fi

print_step "Verify live Render health endpoint"

printf 'Live URL: %s\n' "$LIVE_URL"
live_health_output="$(curl -fsS -i "$LIVE_URL/health/" 2>&1 || true)"
printf '%s\n' "$live_health_output"

assert_output_contains "$live_health_output" "HTTP/" "live health HTTP response"
assert_output_matches "$live_health_output" "HTTP/[0-9.]+ 200" "live health HTTP 200"
assert_output_contains "$live_health_output" '"status": "ok"' "live health status"
assert_output_contains "$live_health_output" '"service": "studybuddy"' "live service"
assert_output_contains "$live_health_output" '"database": "ok"' "live database"

print_step "Verify live home page loads"

assert_http_status "$LIVE_URL/" "200" "Live home page"

print_step "Verify live signup and login pages load under /users/"

assert_http_status "$LIVE_URL/users/signup/" "200" "Live signup page"
assert_http_status "$LIVE_URL/users/login/" "200" "Live login page"

print_step "Verify authenticated live dashboard redirects anonymous users"

dashboard_headers="$(curl -fsS -I "$LIVE_URL/dashboard/" 2>&1 || true)"
printf '%s\n' "$dashboard_headers"

assert_output_matches "$dashboard_headers" "HTTP/[0-9.]+ 302" "live dashboard anonymous redirect"
assert_output_contains "$dashboard_headers" "/users/login/" "live dashboard login target"

print_step "Verify removed /accounts/ auth namespace stays unavailable"

assert_http_status "$LIVE_URL/accounts/login/" "404" "Live legacy accounts login route"

print_step "Verify live static CSS asset is available"

assert_http_status "$LIVE_URL/static/css/theme.css" "200" "Live theme CSS"

print_step "Verify live security headers on health response"

live_headers="$(curl -fsS -I "$LIVE_URL/health/" 2>&1 || true)"
printf '%s\n' "$live_headers"

assert_output_contains "$live_headers" "X-Frame-Options" "live X-Frame-Options"
assert_output_contains "$live_headers" "X-Content-Type-Options" "live X-Content-Type-Options"
assert_output_contains "$live_headers" "Referrer-Policy" "live Referrer-Policy"

print_step "Review web logs for startup errors"

web_logs="$(docker compose logs --tail=100 web)"
printf '%s\n' "$web_logs"

if printf '%s\n' "$web_logs" | grep -Fq "Traceback"; then
  printf 'TRACEBACK found in web logs.\n'
  exit 1
else
  printf 'NO TRACEBACK in web logs\n'
fi

print_step "Confirm database container remains healthy"

db_status="$(docker compose ps db)"
printf '%s\n' "$db_status"

assert_output_contains "$db_status" "db" "database service"
assert_output_contains "$db_status" "healthy" "database health"

print_step "Review database logs for unexpected tracebacks"

db_logs="$(docker compose logs --tail=80 db)"
printf '%s\n' "$db_logs"

if printf '%s\n' "$db_logs" | grep -Fq "Traceback"; then
  printf 'TRACEBACK found in database logs.\n'
  exit 1
else
  printf 'NO TRACEBACK in database logs\n'
fi

print_step "Final receipt"

printf '%s\n' "Repository root verified."
printf '%s\n' "Sprint 4 Day 4 deployment verification files verified."
printf '%s\n' "Deployment docs include Render rationale, platform boundary, production settings, release metadata, collectstatic, migrate, Gunicorn, and health checks."
printf '%s\n' "Final verification docs include live MVP URL, post-deploy health checks, tests, deploy checks, and core product journey."
printf '%s\n' "README references live deployment, Render, release metadata, and health check."
printf '%s\n' "Production settings remain environment-driven and hardened."
printf '%s\n' "Canonical auth namespace is /users/ and duplicate /accounts/ mount is absent."
printf '%s\n' ".env.example documents production variables without committed secrets."
printf '%s\n' "GitHub Actions workflow is present before release verification."
printf '%s\n' "Docker stack builds and starts."
printf '%s\n' "Local Django check passes."
printf '%s\n' "Local migrations apply."
printf '%s\n' "Full project test suite passes."
printf '%s\n' "Production deployment check passes."
printf '%s\n' "Production static collection succeeds."
printf '%s\n' "Collected static assets exist."
printf '%s\n' "Focused health and auth URL tests pass."
printf '%s\n' "Local /health/ returns HTTP 200."
printf '%s\n' "Recent GitHub Actions run succeeded when gh CLI is available."
printf '%s\n' "Current git commit recorded for release traceability."
printf '%s\n' "Live Render /health/ returns HTTP 200."
printf '%s\n' "Live Render database health reports ok."
printf '%s\n' "Live home page loads."
printf '%s\n' "Live signup and login pages load under /users/."
printf '%s\n' "Live dashboard redirects anonymous users to /users/login/."
printf '%s\n' "Legacy /accounts/login/ returns 404."
printf '%s\n' "Live static CSS asset is available."
printf '%s\n' "Live security headers are present."
printf '%s\n' "Web logs contain no traceback."
printf '%s\n' "Database container remains healthy."
printf '%s\n' "Database logs contain no traceback."
printf '%s\n' "Sprint 4 Day 4 Render deployment and release verification complete."
