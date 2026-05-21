#!/usr/bin/env bash

# Sprint 4 Day 3 runbook: production settings, deployment documentation,
# health check, and logging verification.
#
# Execution:
#   chmod +x docs/sprint-runbook/sprint-4/sprint-4-day-3.sh
#   ./docs/sprint-runbook/sprint-4/sprint-4-day-3.sh
#
# Notes:
#   - This script builds and starts the Docker Compose stack.
#   - It verifies local and production settings through the Docker web service.
#   - It uses django-environ because that is the current project dependency.
#   - Local production smoke checks disable database SSL because the Docker
#     Compose PostgreSQL service is not configured for SSL.

set -euo pipefail

PROJECT_DIR="/Users/adrianadewunmi/VSCODE/StudyBuddy-Study-Planner-Project"

PROD_ENV=(
  "DJANGO_SETTINGS_MODULE=config.settings.production"
  "DJANGO_SECRET_KEY=production-check-secret-key-for-local-verification-only-1234567890"
  "DJANGO_DEBUG=False"
  "DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,web"
  "DJANGO_CSRF_TRUSTED_ORIGINS=http://localhost:8000,http://127.0.0.1:8000"
  "DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_local"
  "DATABASE_SSL_REQUIRE=False"
  "DJANGO_SECURE_SSL_REDIRECT=True"
  "DJANGO_SECURE_HSTS_SECONDS=31536000"
  "DJANGO_DEFAULT_FROM_EMAIL=local-deploy-check@example.com"
  "DJANGO_EMAIL_HOST=localhost"
  "RELEASE_SHA=sprint-4-day-3-local"
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

print_step "Verify repository root"

run cd "$PROJECT_DIR"
printf 'Repository root: %s\n' "$(pwd)"

if test "$(basename "$(pwd)")" = "StudyBuddy-Study-Planner-Project"; then
  printf 'FOUND repository root: StudyBuddy-Study-Planner-Project\n'
else
  printf 'Repository root check failed.\n'
  exit 1
fi

print_step "Confirm Sprint 4 Day 3 production readiness files exist"

assert_file_exists "config/settings/base.py"
assert_file_exists "config/settings/local.py"
assert_file_exists "config/settings/production.py"
assert_file_exists "config/urls.py"
assert_file_exists "tests/test_health_check.py"
assert_file_exists "docs/deployment.md"
assert_file_exists "docs/ci.md"
assert_file_exists "README.md"
assert_file_exists ".env.example"
assert_file_exists "requirements.txt"
assert_file_exists "Makefile"
assert_file_exists "Dockerfile"
assert_file_exists "docker-compose.yml"

print_step "Confirm production dependencies are installed through requirements.txt"

requirements_contents="$(cat requirements.txt)"

assert_output_contains "$requirements_contents" "django-environ" "environment configuration dependency"
assert_output_contains "$requirements_contents" "gunicorn" "Gunicorn dependency"
assert_output_contains "$requirements_contents" "whitenoise" "WhiteNoise dependency"
assert_output_contains "$requirements_contents" "psycopg" "PostgreSQL dependency"

print_step "Confirm base settings include shared production-supporting configuration"

base_settings="$(cat config/settings/base.py)"

assert_output_contains "$base_settings" "import environ" "django-environ import"
assert_output_contains "$base_settings" "env.db(\"DATABASE_URL\")" "DATABASE_URL parsing"
assert_output_contains "$base_settings" "DATABASES" "database configuration"
assert_output_contains "$base_settings" "STATIC_ROOT" "static root"
assert_output_contains "$base_settings" "WhiteNoiseMiddleware" "WhiteNoise middleware"
assert_output_contains "$base_settings" "LOGGING" "logging configuration"
assert_output_contains "$base_settings" "RELEASE_SHA" "release metadata"

print_step "Confirm production settings are environment-driven and hardened"

production_settings="$(cat config/settings/production.py)"

assert_output_contains "$production_settings" "DEBUG = False" "production debug disabled"
assert_output_contains "$production_settings" "DJANGO_SECRET_KEY" "environment secret"
assert_output_contains "$production_settings" "DJANGO_ALLOWED_HOSTS" "environment allowed hosts"
assert_output_contains "$production_settings" "DJANGO_CSRF_TRUSTED_ORIGINS" "environment CSRF origins"
assert_output_contains "$production_settings" "DATABASE_URL" "environment database URL"
assert_output_contains "$production_settings" "DATABASE_SSL_REQUIRE" "database SSL switch"
assert_output_contains "$production_settings" "DJANGO_DEFAULT_FROM_EMAIL" "environment default sender"
assert_output_contains "$production_settings" "DJANGO_EMAIL_HOST" "environment SMTP host"
assert_output_contains "$production_settings" "django.core.mail.backends.smtp.EmailBackend" "SMTP email backend"
assert_output_contains "$production_settings" "CompressedManifestStaticFilesStorage" "manifest static storage"
assert_output_contains "$production_settings" "SECURE_PROXY_SSL_HEADER" "proxy SSL header"
assert_output_contains "$production_settings" "SECURE_SSL_REDIRECT" "SSL redirect setting"
assert_output_contains "$production_settings" "SESSION_COOKIE_SECURE" "secure session cookie"
assert_output_contains "$production_settings" "CSRF_COOKIE_SECURE" "secure CSRF cookie"
assert_output_contains "$production_settings" "SECURE_HSTS_SECONDS" "HSTS setting"
assert_output_contains "$production_settings" "SECURE_CONTENT_TYPE_NOSNIFF" "content type nosniff"
assert_output_contains "$production_settings" "X_FRAME_OPTIONS" "frame options"

print_step "Confirm health check route is wired"

urls_contents="$(cat config/urls.py)"

assert_output_contains "$urls_contents" "health_check" "health function"
assert_output_contains "$urls_contents" "health/" "health URL path"
assert_output_contains "$urls_contents" "JsonResponse" "JSON response"
assert_output_contains "$urls_contents" "SELECT 1" "database readiness query"
assert_output_contains "$urls_contents" "database" "database check key"
assert_output_contains "$urls_contents" "503" "degraded response status"

print_step "Confirm health check tests cover success, method safety, and database failure"

health_tests="$(cat tests/test_health_check.py)"

assert_output_contains "$health_tests" "test_health_check_returns_ok_when_database_is_available" "healthy database test"
assert_output_contains "$health_tests" "test_health_check_rejects_non_get_methods" "method safety test"
assert_output_contains "$health_tests" "test_health_check_returns_degraded_when_database_is_unavailable" "database failure test"
assert_output_contains "$health_tests" "status_code == 200" "healthy status assertion"
assert_output_contains "$health_tests" "status_code == 405" "method status assertion"
assert_output_contains "$health_tests" "status_code == 503" "degraded status assertion"

print_step "Confirm deployment documentation describes production runtime"

deployment_docs="$(cat docs/deployment.md)"

assert_output_contains "$deployment_docs" "Deployment" "deployment documentation title"
assert_output_contains "$deployment_docs" "Render" "Render documentation"
assert_output_contains "$deployment_docs" "DJANGO_SETTINGS_MODULE=config.settings.production" "production settings documentation"
assert_output_contains "$deployment_docs" "DATABASE_URL" "database URL documentation"
assert_output_contains "$deployment_docs" "DJANGO_DEFAULT_FROM_EMAIL" "default sender documentation"
assert_output_contains "$deployment_docs" "DJANGO_EMAIL_HOST" "SMTP host documentation"
assert_output_contains "$deployment_docs" "collectstatic" "static collection documentation"
assert_output_contains "$deployment_docs" "gunicorn" "Gunicorn documentation"
assert_output_contains "$deployment_docs" "/health/" "health check documentation"
assert_output_contains "$deployment_docs" "Continuous Integration" "CI documentation link"

print_step "Confirm README references deployment, live URL, and health check"

readme_contents="$(cat README.md)"

assert_output_contains "$readme_contents" "Deployment" "README deployment reference"
assert_output_contains "$readme_contents" "studybuddy-django-app.onrender.com" "README live URL"
assert_output_contains "$readme_contents" "/health/" "README health check reference"

print_step "Build and start Docker/PostgreSQL stack"

run make build
run make up

print_step "Confirm containers are running"

compose_ps="$(docker compose ps)"

printf '%s\n' "$compose_ps"

assert_output_contains "$compose_ps" "db" "compose status db"
assert_output_contains "$compose_ps" "web" "compose status web"
assert_output_contains "$compose_ps" "healthy" "compose database health"

print_step "Run local Django system check"

local_check_output="$(make check 2>&1)"

printf '%s\n' "$local_check_output"

assert_output_contains "$local_check_output" "System check identified no issues" "local Django check receipt"

print_step "Apply local database migrations"

migrate_output="$(make migrate 2>&1)"

printf '%s\n' "$migrate_output"

assert_output_contains "$migrate_output" "Operations to perform:" "migration command receipt"

print_step "Run production deployment checks with production settings"

deploy_check_output="$(
  docker compose exec -T web env "${PROD_ENV[@]}" \
    python manage.py check --deploy --settings=config.settings.production 2>&1
)"

printf '%s\n' "$deploy_check_output"

assert_output_contains "$deploy_check_output" "System check identified no issues" "production deployment check receipt"

print_step "Run static collection with production settings"

collectstatic_output="$(
  docker compose exec -T web env "${PROD_ENV[@]}" \
    python manage.py collectstatic --noinput --settings=config.settings.production 2>&1
)"

printf '%s\n' "$collectstatic_output"

assert_output_matches "$collectstatic_output" "static file|static files|post-processed|unmodified" "collectstatic receipt"

print_step "Confirm staticfiles directory exists and contains collected files"

staticfiles_output="$(
  docker compose exec -T web sh -c 'test -d staticfiles && find staticfiles -type f | head -5'
)"

printf '%s\n' "$staticfiles_output"

assert_output_matches "$staticfiles_output" ".+" "collected static files"

print_step "Run focused health check tests"

health_test_output="$(
  docker compose exec -T web env "${TEST_ENV[@]}" \
    pytest tests/test_health_check.py -q 2>&1
)"

printf '%s\n' "$health_test_output"

assert_output_contains "$health_test_output" "passed" "health check pytest receipt"

print_step "Run full project test suite after production-readiness changes"

test_output="$(make test 2>&1)"

printf '%s\n' "$test_output"

assert_output_contains "$test_output" "passed" "full pytest receipt"

print_step "Verify local health endpoint over HTTP"

health_http_output="$(curl -fsS -i http://localhost:8000/health/)"

printf '%s\n' "$health_http_output"

assert_output_contains "$health_http_output" "HTTP/1.1 200 OK" "health HTTP 200"
assert_output_contains "$health_http_output" '"status": "ok"' "health status ok"
assert_output_contains "$health_http_output" '"service": "studybuddy"' "health service name"
assert_output_contains "$health_http_output" '"database": "ok"' "health database ok"

print_step "Verify health endpoint rejects POST over HTTP"

health_post_status="$(curl -fsS -o /dev/null -w '%{http_code}' -X POST http://localhost:8000/health/ || true)"

printf 'POST /health/ HTTP status: %s\n' "$health_post_status"

if test "$health_post_status" = "403" || test "$health_post_status" = "405"; then
  printf 'FOUND health POST rejection: %s\n' "$health_post_status"
else
  printf 'Expected POST /health/ to be rejected with 403 or 405 but got %s\n' "$health_post_status"
  exit 1
fi

print_step "Confirm production settings can import without leaking DEBUG true"

prod_debug_output="$(
  docker compose exec -T web env "${PROD_ENV[@]}" \
    python manage.py shell --settings=config.settings.production -c \
    'from django.conf import settings; print(f"DEBUG={settings.DEBUG}"); print(f"ALLOWED_HOSTS={settings.ALLOWED_HOSTS}"); print(f"SECURE_SSL_REDIRECT={settings.SECURE_SSL_REDIRECT}")'
)"

printf '%s\n' "$prod_debug_output"

assert_output_contains "$prod_debug_output" "DEBUG=False" "production DEBUG false"
assert_output_contains "$prod_debug_output" "SECURE_SSL_REDIRECT=True" "production SSL redirect true"

print_step "Confirm logging configuration is available from Django settings"

logging_output="$(
  docker compose exec -T web env "${PROD_ENV[@]}" \
    python manage.py shell --settings=config.settings.production -c \
    'from django.conf import settings; print(settings.LOGGING["handlers"].keys()); print(settings.LOGGING["root"]["level"])'
)"

printf '%s\n' "$logging_output"

assert_output_contains "$logging_output" "console" "console logging handler"
assert_output_contains "$logging_output" "INFO" "logging level"

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

assert_output_contains "$db_status" "db" "database service status"
assert_output_contains "$db_status" "healthy" "database health status"

print_step "Review database logs for unexpected tracebacks"

db_logs="$(docker compose logs --tail=80 db)"

printf '%s\n' "$db_logs"

if printf '%s\n' "$db_logs" | grep -Fq "Traceback"; then
  printf 'TRACEBACK found in database logs.\n'
  exit 1
else
  printf 'NO TRACEBACK in database logs\n'
fi

print_step "Confirm working tree status for review"

git_status_output="$(git status --short)"

if test -z "$git_status_output"; then
  printf 'Working tree clean.\n'
else
  printf 'Working tree has changes:\n%s\n' "$git_status_output"
fi

print_step "Final receipt"

printf '%s\n' "Repository root verified."
printf '%s\n' "Sprint 4 Day 3 production readiness files verified."
printf '%s\n' "Production dependencies verified."
printf '%s\n' "Base settings include database, static, WhiteNoise, release, and logging support."
printf '%s\n' "Production settings are environment-driven."
printf '%s\n' "Production settings include secure cookie, HSTS, proxy SSL, and static storage configuration."
printf '%s\n' "Health check route is wired at /health/."
printf '%s\n' "Health check tests cover healthy, rejected method, and degraded database cases."
printf '%s\n' "Deployment documentation describes Render, production settings, environment variables, collectstatic, Gunicorn, and health checks."
printf '%s\n' "Docker stack builds and starts."
printf '%s\n' "Local Django check passes."
printf '%s\n' "Local migrations apply."
printf '%s\n' "Production deployment check passes."
printf '%s\n' "Production static collection succeeds."
printf '%s\n' "Collected static files exist."
printf '%s\n' "Focused health check tests pass."
printf '%s\n' "Full project test suite passes."
printf '%s\n' "GET /health/ returns HTTP 200."
printf '%s\n' "POST /health/ is rejected over HTTP."
printf '%s\n' "Production settings import with DEBUG=False."
printf '%s\n' "Production logging configuration is available."
printf '%s\n' "Web logs contain no traceback."
printf '%s\n' "Database container remains healthy."
printf '%s\n' "Database logs contain no traceback."
printf '%s\n' "Sprint 4 Day 3 production settings, health check, and logging verification complete."
