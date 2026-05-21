#!/usr/bin/env bash
#
# Sprint 4 Day 5 runbook: final MVP release verification and guarded tagging.
#
# Usage:
#   chmod +x docs/sprint-runbook/sprint-4/sprint-4-day-5.sh
#   ./docs/sprint-runbook/sprint-4/sprint-4-day-5.sh
#
# If Render generated a different service URL:
#   LIVE_URL="https://your-render-service.onrender.com" \
#     ./docs/sprint-runbook/sprint-4/sprint-4-day-5.sh
#
# After the PR is merged, the working tree is clean, and this runbook passes
# from the release branch:
#   CREATE_RELEASE_TAG=true ./docs/sprint-runbook/sprint-4/sprint-4-day-5.sh
#
# This script intentionally fails when the live Render URL is not routed. A
# response such as `x-render-routing: no-server` means the local/repo checks may
# be healthy, but the deployed service URL is not release-verified yet.

set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
LIVE_URL="${LIVE_URL:-https://studybuddy-django-app.onrender.com}"
RELEASE_TAG="${RELEASE_TAG:-v0.1.0-mvp}"
EXPECTED_RELEASE_BRANCH="${EXPECTED_RELEASE_BRANCH:-main}"
CREATE_RELEASE_TAG="${CREATE_RELEASE_TAG:-false}"

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
  "RENDER_GIT_COMMIT=sprint-4-day-5-local"
  "RELEASE_SHA=sprint-4-day-5-local"
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

print_step "Confirm final release documentation and config files exist"

assert_file_exists "README.md"
assert_file_exists "RUNBOOK.md"
assert_file_exists "docs/architecture.md"
assert_file_exists "docs/ai-nlp-contract.md"
assert_file_exists "docs/ci.md"
assert_file_exists "docs/deployment.md"
assert_file_exists "docs/demo-script.md"
assert_file_exists "docs/final-verification.md"
assert_file_exists "docs/local-setup.md"
assert_file_exists ".env.example"
assert_file_exists "requirements.txt"
assert_file_exists "pyproject.toml"
assert_file_exists "pytest.ini"
assert_file_exists "Dockerfile"
assert_file_exists "docker-compose.yml"
assert_file_exists "render.yaml"
assert_file_exists "Makefile"
assert_file_exists ".github/workflows/ci.yml"
assert_file_exists ".github/dependabot.yml"

print_step "Confirm README contains current MVP release sections"

readme_contents="$(cat README.md)"

assert_output_contains "$readme_contents" "StudyBuddy" "README product name"
assert_output_contains "$readme_contents" "Live MVP URL" "README live deployment reference"
assert_output_contains "$readme_contents" "Current verification tag: \`$RELEASE_TAG\`" "README release tag"
assert_output_contains "$readme_contents" "Product Summary" "README product summary"
assert_output_contains "$readme_contents" "Deployment" "README deployment section"
assert_output_contains "$readme_contents" "Docker" "README Docker section"
assert_output_contains "$readme_contents" "GitHub Actions" "README CI reference"
assert_output_contains "$readme_contents" "Codecov" "README Codecov reference"
assert_output_contains "$readme_contents" "PostgreSQL" "README PostgreSQL reference"
assert_output_contains "$readme_contents" "AI/NLP" "README AI/NLP reference"
assert_output_contains "$readme_contents" "MVP" "README MVP scope reference"
assert_output_contains "$readme_contents" "Next Steps" "README next steps"
assert_output_contains "$readme_contents" "/health/" "README health endpoint"
assert_output_contains "$readme_contents" "Dependabot" "README dependency automation"

print_step "Confirm architecture documentation is current"

architecture_docs="$(cat docs/architecture.md)"

assert_output_contains "$architecture_docs" "Architecture" "architecture title"
assert_output_contains "$architecture_docs" "users" "users app boundary"
assert_output_contains "$architecture_docs" "roles" "roles app boundary"
assert_output_contains "$architecture_docs" "dashboard" "dashboard app boundary"
assert_output_contains "$architecture_docs" "sessions" "sessions app boundary"
assert_output_contains "$architecture_docs" "insights" "insights app boundary"
assert_output_contains "$architecture_docs" "PostgreSQL" "database architecture"
assert_output_contains "$architecture_docs" "Docker" "Docker architecture"
assert_output_contains "$architecture_docs" "Render" "deployment architecture"
assert_output_contains "$architecture_docs" "ownership" "ownership rule"
assert_output_contains "$architecture_docs" "docs/final-verification.md" "current release proof"

print_step "Confirm AI/NLP contract documentation is complete"

ai_docs="$(cat docs/ai-nlp-contract.md)"

assert_output_contains "$ai_docs" "AI/NLP" "AI/NLP title"
assert_output_contains "$ai_docs" "deterministic" "deterministic contract"
assert_output_contains "$ai_docs" "keyword" "keyword contract"
assert_output_contains "$ai_docs" "summary" "summary contract"
assert_output_contains "$ai_docs" "confidence" "confidence contract"
assert_output_contains "$ai_docs" "source" "source hash contract"
assert_output_contains "$ai_docs" "explanation" "explanation contract"
assert_output_contains "$ai_docs" "Ownership" "ownership contract"
assert_output_contains "$ai_docs" "Verification Commands" "testing contract"

print_step "Confirm deployment documentation matches Render Docker runtime"

deployment_docs="$(cat docs/deployment.md)"

assert_output_contains "$deployment_docs" "Deployment" "deployment title"
assert_output_contains "$deployment_docs" "Why Render" "Render rationale"
assert_output_contains "$deployment_docs" "Platform Boundary" "platform boundary"
assert_output_contains "$deployment_docs" "render.yaml" "Render Blueprint reference"
assert_output_contains "$deployment_docs" "DJANGO_SETTINGS_MODULE=config.settings.production" "production settings"
assert_output_contains "$deployment_docs" "DATABASE_URL" "database URL"
assert_output_contains "$deployment_docs" "DJANGO_DEFAULT_FROM_EMAIL" "production email sender"
assert_output_contains "$deployment_docs" "DJANGO_EMAIL_HOST" "production SMTP host"
assert_output_contains "$deployment_docs" "collectstatic" "static collection"
assert_output_contains "$deployment_docs" "migrate" "migration command"
assert_output_contains "$deployment_docs" "gunicorn" "Gunicorn command"
assert_output_contains "$deployment_docs" "/health/" "health check"

print_step "Confirm demo script covers the full MVP journey"

demo_docs="$(cat docs/demo-script.md)"

assert_output_contains "$demo_docs" "Demo" "demo title"
assert_output_contains "$demo_docs" "/users/signup/" "signup step"
assert_output_contains "$demo_docs" "/dashboard/" "dashboard step"
assert_output_contains "$demo_docs" "study session" "session step"
assert_output_contains "$demo_docs" "note" "note step"
assert_output_contains "$demo_docs" "insight" "insight step"
assert_output_contains "$demo_docs" "metrics" "metrics step"
assert_output_contains "$demo_docs" "/health/" "health check step"
assert_output_contains "$demo_docs" "x-render-routing: no-server" "unrouted Render warning"

print_step "Confirm final verification documentation records release evidence"

final_verification_docs="$(cat docs/final-verification.md)"

assert_output_contains "$final_verification_docs" "Final Verification" "final verification title"
assert_output_contains "$final_verification_docs" "Live MVP URL" "live URL section"
assert_output_contains "$final_verification_docs" "$RELEASE_TAG" "release tag reference"
assert_output_contains "$final_verification_docs" "coverage.xml" "coverage evidence"
assert_output_contains "$final_verification_docs" "/health/" "health verification"
assert_output_contains "$final_verification_docs" "pytest" "test verification"
assert_output_contains "$final_verification_docs" "check --deploy" "production check"
assert_output_contains "$final_verification_docs" "Sign up with a test email address" "signup smoke verification"
assert_output_contains "$final_verification_docs" "Create a study session" "session smoke verification"
assert_output_contains "$final_verification_docs" "Add a note" "note smoke verification"
assert_output_contains "$final_verification_docs" "Generate an insight" "insight smoke verification"
assert_output_contains "$final_verification_docs" "RENDER_GIT_COMMIT" "Render release metadata"

print_step "Confirm runbook documentation references current release verification"

runbook_docs="$(cat RUNBOOK.md)"

assert_output_contains "$runbook_docs" "runbook" "runbook wording"
assert_output_contains "$runbook_docs" "Docker" "Docker runbook reference"
assert_output_contains "$runbook_docs" "pytest" "pytest runbook reference"
assert_output_contains "$runbook_docs" "health" "health runbook reference"
assert_output_contains "$runbook_docs" "release verification" "release verification reference"

print_step "Confirm Render Blueprint is present and production-oriented"

render_blueprint="$(cat render.yaml)"

assert_output_contains "$render_blueprint" "services:" "Render services"
assert_output_contains "$render_blueprint" "type: web" "Render web service"
assert_output_contains "$render_blueprint" "runtime: docker" "Render Docker runtime"
assert_output_contains "$render_blueprint" "dockerfilePath: ./Dockerfile" "Render Dockerfile path"
assert_output_contains "$render_blueprint" "dockerContext: ." "Render Docker context"
assert_output_contains "$render_blueprint" "preDeployCommand: python manage.py migrate --noinput" "Render migration command"
assert_output_contains "$render_blueprint" "envVars:" "Render environment variables"
assert_output_contains "$render_blueprint" "healthCheckPath: /health/" "Render health check path"
assert_output_contains "$render_blueprint" "DATABASE_URL" "Render database URL"
assert_output_contains "$render_blueprint" "DJANGO_SETTINGS_MODULE" "Render settings module"
assert_output_contains "$render_blueprint" "DJANGO_DEFAULT_FROM_EMAIL" "Render email sender"
assert_output_contains "$render_blueprint" "DJANGO_EMAIL_HOST" "Render SMTP host"
assert_output_contains "$render_blueprint" "databases:" "Render database resource"

if printf '%s\n' "$render_blueprint" | grep -Eq '(^|[[:space:]])buildCommand:|(^|[[:space:]])startCommand:|(^|[[:space:]])env:'; then
  printf 'Unexpected non-Docker Render command key found in render.yaml.\n'
  exit 1
else
  printf 'NO stale non-Docker Render command keys found.\n'
fi

print_step "Confirm environment example contains no committed production secrets"

env_example="$(cat .env.example)"

assert_output_contains "$env_example" "DJANGO_SETTINGS_MODULE=config.settings.production" "production settings example"
assert_output_contains "$env_example" "DJANGO_DEBUG=false" "production debug example"
assert_output_contains "$env_example" "DJANGO_ALLOWED_HOSTS" "allowed hosts example"
assert_output_contains "$env_example" "DJANGO_CSRF_TRUSTED_ORIGINS" "CSRF origins example"
assert_output_contains "$env_example" "DATABASE_URL" "database URL example"
assert_output_contains "$env_example" "DJANGO_DEFAULT_FROM_EMAIL" "default sender example"
assert_output_contains "$env_example" "DJANGO_EMAIL_HOST" "SMTP host example"
assert_output_matches "$env_example" "RENDER_GIT_COMMIT|RELEASE_SHA" "release metadata example"

if printf '%s\n' "$env_example" | grep -Eiq 'password=[^[:space:]]{12,}|secret=[^[:space:]]{20,}|sk-[A-Za-z0-9]'; then
  printf 'Potential committed secret found in .env.example.\n'
  exit 1
else
  printf 'NO committed production secret pattern found in .env.example\n'
fi

print_step "Confirm Sprint 4 runbook scripts exist for all five days"

assert_file_exists "docs/sprint-runbook/sprint-4/sprint-4-day-1.sh"
assert_file_exists "docs/sprint-runbook/sprint-4/sprint-4-day-2.sh"
assert_file_exists "docs/sprint-runbook/sprint-4/sprint-4-day-3.sh"
assert_file_exists "docs/sprint-runbook/sprint-4/sprint-4-day-4.sh"
assert_file_exists "docs/sprint-runbook/sprint-4/sprint-4-day-5.sh"

print_step "Build and start Docker/PostgreSQL stack"

run make build
run make up

print_step "Confirm containers are running"

compose_ps="$(docker compose ps)"
printf '%s\n' "$compose_ps"

assert_output_contains "$compose_ps" "db" "compose db"
assert_output_contains "$compose_ps" "web" "compose web"
assert_output_contains "$compose_ps" "healthy" "compose database health"

print_step "Run formatting and lint checks"

format_output="$(make format-check 2>&1)"
printf '%s\n' "$format_output"
assert_output_contains "$format_output" "left unchanged" "Black format receipt"

lint_output="$(make lint 2>&1)"
printf '%s\n' "$lint_output"
assert_output_contains "$lint_output" "All checks passed" "Ruff lint receipt"

print_step "Run local Django system check"

local_check_output="$(make check 2>&1)"
printf '%s\n' "$local_check_output"
assert_output_contains "$local_check_output" "System check identified no issues" "local Django check"

print_step "Confirm migration files are up to date"

migration_check_output="$(make check-migrations 2>&1)"
printf '%s\n' "$migration_check_output"
assert_output_contains "$migration_check_output" "No changes detected" "migration drift check"

print_step "Apply local database migrations"

migrate_output="$(make migrate 2>&1)"
printf '%s\n' "$migrate_output"
assert_output_contains "$migrate_output" "Operations to perform:" "migration receipt"

print_step "Run full project test suite"

test_output="$(make test 2>&1)"
printf '%s\n' "$test_output"
assert_output_matches "$test_output" "[0-9]+ passed" "full pytest receipt"

print_step "Run complete local CI quality gate"

ci_output="$(make ci 2>&1)"
printf '%s\n' "$ci_output"

assert_output_contains "$ci_output" "All checks passed" "Ruff receipt from make ci"
assert_output_contains "$ci_output" "System check identified no issues" "Django receipt from make ci"
assert_output_contains "$ci_output" "No changes detected" "migration receipt from make ci"
assert_output_contains "$ci_output" "Coverage XML written to file coverage.xml" "coverage XML receipt"
assert_output_matches "$ci_output" "[0-9]+ passed" "pytest receipt from make ci"

print_step "Run production deployment check"

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
assert_output_matches "$collectstatic_output" "static file|static files|post-processed|unmodified" "collectstatic receipt"

print_step "Run focused release verification tests"

focused_test_output="$(
  docker compose exec -T web env "${TEST_ENV[@]}" \
    pytest tests/test_health_check.py apps/users/tests apps/sessions/tests apps/insights/tests -q 2>&1
)"
printf '%s\n' "$focused_test_output"
assert_output_matches "$focused_test_output" "[0-9]+ passed" "focused release tests"

print_step "Verify local health endpoint"

local_health_output="$(curl -fsS -i http://localhost:8000/health/)"
printf '%s\n' "$local_health_output"

assert_output_contains "$local_health_output" "HTTP/1.1 200 OK" "local health HTTP 200"
assert_output_contains "$local_health_output" '"status": "ok"' "local health status"
assert_output_contains "$local_health_output" '"service": "studybuddy"' "local service"
assert_output_contains "$local_health_output" '"database": "ok"' "local database"

print_step "Verify local public routes are reachable"

assert_http_status "http://localhost:8000/" "200" "Local home page"
assert_http_status "http://localhost:8000/users/signup/" "200" "Local signup page"
assert_http_status "http://localhost:8000/users/login/" "200" "Local login page"

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

print_step "Verify live deployment health endpoint"

printf 'Live URL: %s\n' "$LIVE_URL"
live_health_output="$(curl -fsS -i "$LIVE_URL/health/" 2>&1 || true)"
printf '%s\n' "$live_health_output"

assert_output_contains "$live_health_output" "HTTP/" "live health HTTP response"
assert_output_matches "$live_health_output" "HTTP/[0-9.]+ 200" "live health HTTP 200"
assert_output_contains "$live_health_output" '"status": "ok"' "live health status"
assert_output_contains "$live_health_output" '"service": "studybuddy"' "live service"
assert_output_contains "$live_health_output" '"database": "ok"' "live database"

print_step "Verify live public routes"

assert_http_status "$LIVE_URL/" "200" "Live home page"
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

print_step "Verify live security headers"

live_headers="$(curl -fsS -I "$LIVE_URL/health/" 2>&1 || true)"
printf '%s\n' "$live_headers"

assert_output_contains "$live_headers" "X-Frame-Options" "live X-Frame-Options"
assert_output_contains "$live_headers" "X-Content-Type-Options" "live X-Content-Type-Options"
assert_output_contains "$live_headers" "Referrer-Policy" "live Referrer-Policy"

print_step "Confirm current branch and commit"

current_branch="$(git branch --show-current)"
current_commit="$(git rev-parse --short HEAD)"

printf 'Current branch: %s\n' "$current_branch"
printf 'Current commit: %s\n' "$current_commit"

if test -z "$current_commit"; then
  printf 'Could not resolve current commit.\n'
  exit 1
fi

print_step "Confirm remote origin points to StudyBuddy repository"

remote_origin="$(git remote get-url origin 2>/dev/null || true)"
printf 'Remote origin: %s\n' "$remote_origin"
assert_output_matches "$remote_origin" "[sS]tudy[bB]uddy" "StudyBuddy remote origin"

print_step "Check working tree status"

git_status_output="$(git status --short)"

if test -z "$git_status_output"; then
  printf 'Working tree clean.\n'
else
  printf 'Working tree has changes:\n%s\n' "$git_status_output"
fi

print_step "Check release branch readiness"

if test "$current_branch" = "$EXPECTED_RELEASE_BRANCH"; then
  printf 'FOUND release branch: %s\n' "$EXPECTED_RELEASE_BRANCH"
else
  printf 'Current branch is %s, expected %s for release tagging.\n' \
    "$current_branch" "$EXPECTED_RELEASE_BRANCH"
  printf 'Complete the pull request merge first, then run this runbook from %s.\n' \
    "$EXPECTED_RELEASE_BRANCH"
fi

print_step "Check release tag status"

if git rev-parse "$RELEASE_TAG" >/dev/null 2>&1; then
  printf 'FOUND existing release tag: %s\n' "$RELEASE_TAG"
else
  printf 'Release tag does not exist yet: %s\n' "$RELEASE_TAG"

  if test "$CREATE_RELEASE_TAG" = "true"; then
    if test "$current_branch" != "$EXPECTED_RELEASE_BRANCH"; then
      printf 'Refusing to create release tag from branch %s. Expected %s.\n' \
        "$current_branch" "$EXPECTED_RELEASE_BRANCH"
      exit 1
    fi

    if test -n "$git_status_output"; then
      printf 'Refusing to create release tag with a non-clean working tree.\n'
      exit 1
    fi

    printf 'Creating release tag: %s\n' "$RELEASE_TAG"
    git tag "$RELEASE_TAG"
    git push origin "$RELEASE_TAG"
    printf 'FOUND release tag created and pushed: %s\n' "$RELEASE_TAG"
  else
    printf 'Release tag creation skipped. To create it after all gates pass, run:\n'
    printf 'CREATE_RELEASE_TAG=true ./docs/sprint-runbook/sprint-4/sprint-4-day-5.sh\n'
  fi
fi

print_step "Review web logs for startup errors"

web_logs="$(docker compose logs --tail=120 web)"
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
printf '%s\n' "Final release documentation and config files verified."
printf '%s\n' "README contains current MVP release sections and verification tag."
printf '%s\n' "Architecture documentation is current."
printf '%s\n' "AI/NLP contract documentation is complete."
printf '%s\n' "Deployment documentation matches the Render Docker runtime."
printf '%s\n' "Demo script covers the full MVP journey."
printf '%s\n' "Final verification documentation records release evidence."
printf '%s\n' "RUNBOOK references current release verification."
printf '%s\n' "Render Blueprint is present and Docker-oriented."
printf '%s\n' ".env.example contains no committed production secrets."
printf '%s\n' "Sprint 4 runbook scripts exist for all five days."
printf '%s\n' "Docker stack builds and starts."
printf '%s\n' "Black formatting check passes."
printf '%s\n' "Ruff lint check passes."
printf '%s\n' "Local Django check passes."
printf '%s\n' "Migration drift check reports no changes."
printf '%s\n' "Local migrations apply."
printf '%s\n' "Full project test suite passes."
printf '%s\n' "Complete local CI quality gate passes."
printf '%s\n' "Production deployment check passes."
printf '%s\n' "Production static collection succeeds."
printf '%s\n' "Focused release verification tests pass."
printf '%s\n' "Local /health/ returns HTTP 200."
printf '%s\n' "Local signup and login routes are reachable."
printf '%s\n' "Recent GitHub Actions run succeeded when gh CLI is available."
printf '%s\n' "Live deployment /health/ returns HTTP 200."
printf '%s\n' "Live deployment database health reports ok."
printf '%s\n' "Live home page loads."
printf '%s\n' "Live signup and login routes are reachable."
printf '%s\n' "Live dashboard redirects anonymous users to /users/login/."
printf '%s\n' "Legacy /accounts/login/ returns 404."
printf '%s\n' "Live static CSS asset is available."
printf '%s\n' "Live security headers are present."
printf '%s\n' "Current git commit recorded."
printf '%s\n' "Release tag status checked."
printf '%s\n' "Web logs contain no traceback."
printf '%s\n' "Database container remains healthy."
printf '%s\n' "Database logs contain no traceback."
printf '%s\n' "Final documentation, demo narrative, MVP release verification, and release tag gate complete."
