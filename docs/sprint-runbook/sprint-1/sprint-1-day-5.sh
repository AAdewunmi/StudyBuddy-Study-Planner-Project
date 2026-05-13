#!/usr/bin/env bash
#
# Sprint 1 Day 5 Console-Only Verification Runbook
#
# Purpose:
#   Verify the StudyBuddy protected dashboard, role-aware permission helpers,
#   dashboard/profile integration paths, and current test baseline
#   using the current Docker + PostgreSQL workflow.
#
# Execution command:
#
#   ./docs/sprint-runbook/sprint-1/sprint-1-day-5.sh
#
# If the file is not executable, run:
#
#   chmod +x docs/sprint-runbook/sprint-1/sprint-1-day-5.sh
#
# Notes:
#   - Run from anywhere inside the repository.
#   - Docker Desktop or a compatible Docker daemon must be running.
#   - This project copies source into the Docker image, so the script rebuilds
#     the web service before verification.
#   - The current full pytest baseline may exceed the original Sprint 1 count
#     because later sprint workflow tests remain in the project.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_ROOT_NAME="StudyBuddy-Study-Planner-Project"
VERIFY_USER_EMAIL="friday.dashboard@example.com"
VERIFY_ADMIN_EMAIL="friday.admin@example.com"
VERIFY_ROLE_SLUG="friday-student"
VERIFY_ROLE_NAME="Friday Student"

section() {
    printf '\n==> %s\n' "$1"
}

run() {
    printf '\n$ %s\n' "$*"
    "$@"
}

capture() {
    printf '\n$ %s\n' "$*" >&2
    "$@" 2>&1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"

    if [[ "$haystack" != *"$needle"* ]]; then
        printf 'Expected output to include: %s\n' "$needle" >&2
        printf 'Actual output:\n%s\n' "$haystack" >&2
        exit 1
    fi
}

assert_not_exists() {
    local path="$1"

    if [[ -e "$PROJECT_ROOT/$path" ]]; then
        printf 'Unexpected obsolete path exists: %s\n' "$path" >&2
        exit 1
    fi

    printf 'OK absent: %s\n' "$path"
}

section "Verify repository root"
run cd "$PROJECT_ROOT"
printf 'Repository root: %s\n' "$PROJECT_ROOT"

if [[ "$(basename "$PROJECT_ROOT")" != "$EXPECTED_ROOT_NAME" ]]; then
    printf 'Expected repository directory to end with: %s\n' "$EXPECTED_ROOT_NAME" >&2
    printf 'Actual repository directory: %s\n' "$(basename "$PROJECT_ROOT")" >&2
    exit 1
fi

section "Verify required Friday dashboard and access-control files"
required_files=(
    "apps/dashboard/apps.py"
    "apps/dashboard/views.py"
    "apps/dashboard/urls.py"
    "apps/dashboard/tests/__init__.py"
    "apps/dashboard/tests/test_dashboard_views.py"
    "apps/roles/permissions.py"
    "apps/roles/tests/test_models.py"
    "apps/users/factories.py"
    "config/urls.py"
    "docs/authentication.md"
    "static/css/theme.css"
    "templates/base.html"
    "templates/dashboard/index.html"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        printf 'Missing required file: %s\n' "$file" >&2
        exit 1
    fi

    printf 'OK: %s\n' "$file"
done

section "Verify obsolete or stale paths are absent"
assert_not_exists "templates/registration/login.html"
assert_not_exists "templates/registration/signup.html"
assert_not_exists "apps/staticfiles"

section "Start Docker/PostgreSQL stack"
run docker compose up -d --build
run docker compose ps

section "Verify Django system health"
local_check_output="$(
    capture docker compose exec -T web python manage.py check --settings=config.settings.local
)"
printf '%s\n' "$local_check_output"
assert_contains "$local_check_output" "System check identified no issues"

test_check_output="$(
    capture docker compose exec -T web python manage.py check --settings=config.settings.test
)"
printf '%s\n' "$test_check_output"
assert_contains "$test_check_output" "System check identified no issues"

section "Verify dashboard app registration and route resolution"
dashboard_config_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.apps import apps; print(apps.get_app_config('dashboard').name)"
)"
printf '%s\n' "$dashboard_config_output"
assert_contains "$dashboard_config_output" "apps.dashboard"

dashboard_url_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.urls import resolve, reverse; print(reverse('dashboard:index')); print(resolve('/dashboard/').view_name)"
)"
printf '%s\n' "$dashboard_url_output"
assert_contains "$dashboard_url_output" "/dashboard/"
assert_contains "$dashboard_url_output" "dashboard:index"

section "Verify dashboard and base templates can be discovered"
template_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.template.loader import get_template; templates=['base.html','dashboard/index.html']; [print(f'template OK: {name}') for name in templates if get_template(name)]"
)"
printf '%s\n' "$template_output"
assert_contains "$template_output" "template OK: base.html"
assert_contains "$template_output" "template OK: dashboard/index.html"

section "Verify static CSS exists inside the container"
run docker compose exec -T web test -f static/css/theme.css
printf 'container static CSS OK: static/css/theme.css\n'

section "Clean previous Friday verification data"
cleanup_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from apps.roles.models import Role; User=get_user_model(); User.objects.filter(email__in=['$VERIFY_USER_EMAIL','$VERIFY_ADMIN_EMAIL']).delete(); Role.objects.filter(slug='$VERIFY_ROLE_SLUG').delete(); print('previous Friday verification data removed')"
)"
printf '%s\n' "$cleanup_output"
assert_contains "$cleanup_output" "previous Friday verification data removed"

section "Verify dashboard redirects anonymous users"
anonymous_dashboard_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.test import Client; from django.urls import reverse; client=Client(HTTP_HOST='localhost'); response=client.get(reverse('dashboard:index')); print(f'dashboard_anonymous_status={response.status_code}'); print(f'dashboard_anonymous_redirect={response.headers.get(\"Location\")}')"
)"
printf '%s\n' "$anonymous_dashboard_output"
assert_contains "$anonymous_dashboard_output" "dashboard_anonymous_status=302"
assert_contains "$anonymous_dashboard_output" "/users/login/?next=/dashboard/"

section "Verify authenticated dashboard renders"
dashboard_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); User.objects.filter(email='$VERIFY_USER_EMAIL').delete(); user=User.objects.create_user(email='$VERIFY_USER_EMAIL', password='StrongPassword123!'); client=Client(HTTP_HOST='localhost'); client.force_login(user); response=client.get(reverse('dashboard:index')); body=response.content.decode(); print(f'dashboard_authenticated_status={response.status_code}'); print('Your study dashboard' in body); print('No study sessions yet' in body); print('No product roles have been assigned yet.' in body)"
)"
printf '%s\n' "$dashboard_output"
assert_contains "$dashboard_output" "dashboard_authenticated_status=200"
assert_contains "$dashboard_output" "True"

section "Verify dashboard appears after login"
login_dashboard_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); user=User.objects.get(email='$VERIFY_USER_EMAIL'); client=Client(HTTP_HOST='localhost'); response=client.post(reverse('users:login'), {'username': user.email, 'password': 'StrongPassword123!'}, follow=True); body=response.content.decode(); print(f'login_to_dashboard_status={response.status_code}'); print(f'login_redirect_chain={response.redirect_chain}'); print('Your study dashboard' in body)"
)"
printf '%s\n' "$login_dashboard_output"
assert_contains "$login_dashboard_output" "login_to_dashboard_status=200"
assert_contains "$login_dashboard_output" "('/dashboard/', 302)"
assert_contains "$login_dashboard_output" "True"

section "Verify authenticated dashboard navigation"
auth_nav_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); user=User.objects.get(email='$VERIFY_USER_EMAIL'); client=Client(HTTP_HOST='localhost'); client.force_login(user); response=client.get(reverse('dashboard:index')); body=response.content.decode(); print('Dashboard' in body); print('Profile' in body); print('Log Out' in body)"
)"
printf '%s\n' "$auth_nav_output"
assert_contains "$auth_nav_output" "True"

section "Verify public navigation"
public_nav_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.test import Client; from django.urls import reverse; client=Client(HTTP_HOST='localhost'); response=client.get(reverse('home')); body=response.content.decode(); print(f'home_status={response.status_code}'); print('Log In' in body); print('Create Account' in body)"
)"
printf '%s\n' "$public_nav_output"
assert_contains "$public_nav_output" "home_status=200"
assert_contains "$public_nav_output" "True"

section "Verify role permission helper imports"
permission_import_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from apps.roles.permissions import role_required, user_has_any_role, user_has_role; print('role permission helpers import OK')"
)"
printf '%s\n' "$permission_import_output"
assert_contains "$permission_import_output" "role permission helpers import OK"

section "Verify anonymous users fail role checks"
anonymous_role_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth.models import AnonymousUser; from apps.roles.permissions import user_has_any_role, user_has_role; user=AnonymousUser(); print(user_has_role(user, '$VERIFY_ROLE_SLUG')); print(user_has_any_role(user, ['$VERIFY_ROLE_SLUG', 'admin']))"
)"
printf '%s\n' "$anonymous_role_output"
assert_contains "$anonymous_role_output" "False"

section "Verify superusers pass role checks"
superuser_role_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from apps.roles.permissions import user_has_any_role, user_has_role; User=get_user_model(); User.objects.filter(email='$VERIFY_ADMIN_EMAIL').delete(); user=User.objects.create_superuser(email='$VERIFY_ADMIN_EMAIL', password='StrongPassword123!'); print(user_has_role(user, '$VERIFY_ROLE_SLUG')); print(user_has_any_role(user, ['$VERIFY_ROLE_SLUG', 'admin']))"
)"
printf '%s\n' "$superuser_role_output"
assert_contains "$superuser_role_output" "True"

section "Verify normal users without roles fail role checks"
user_without_role_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from apps.roles.permissions import user_has_any_role, user_has_role; User=get_user_model(); user=User.objects.get(email='$VERIFY_USER_EMAIL'); user.studybuddy_roles.clear(); print(user_has_role(user, '$VERIFY_ROLE_SLUG')); print(user_has_any_role(user, ['$VERIFY_ROLE_SLUG', 'admin']))"
)"
printf '%s\n' "$user_without_role_output"
assert_contains "$user_without_role_output" "False"

section "Verify normal users with roles pass role checks"
user_with_role_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from apps.roles.models import Role; from apps.roles.permissions import user_has_any_role, user_has_role; User=get_user_model(); user=User.objects.get(email='$VERIFY_USER_EMAIL'); Role.objects.filter(slug='$VERIFY_ROLE_SLUG').delete(); role=Role.objects.create(slug='$VERIFY_ROLE_SLUG', display_name='$VERIFY_ROLE_NAME', description='Verification role for Friday runbook.'); role.users.add(user); print(user_has_role(user, '$VERIFY_ROLE_SLUG')); print(user_has_any_role(user, ['$VERIFY_ROLE_SLUG', 'admin']))"
)"
printf '%s\n' "$user_with_role_output"
assert_contains "$user_with_role_output" "True"

section "Verify role relationship appears on dashboard"
dashboard_role_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); user=User.objects.get(email='$VERIFY_USER_EMAIL'); client=Client(HTTP_HOST='localhost'); client.force_login(user); response=client.get(reverse('dashboard:index')); body=response.content.decode(); print(f'dashboard_with_role_status={response.status_code}'); print('$VERIFY_ROLE_NAME' in body)"
)"
printf '%s\n' "$dashboard_role_output"
assert_contains "$dashboard_role_output" "dashboard_with_role_status=200"
assert_contains "$dashboard_role_output" "True"

section "Verify role decorator denies users without role"
decorator_denies_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.core.exceptions import PermissionDenied; from django.http import HttpResponse; from django.test import RequestFactory; from apps.roles.permissions import role_required; User=get_user_model(); user=User.objects.get(email='$VERIFY_USER_EMAIL'); user.studybuddy_roles.clear(); request=RequestFactory().get('/protected/'); request.user=user; protected=role_required('$VERIFY_ROLE_SLUG')(lambda request: HttpResponse('allowed')); exec(\"try:\\n    protected(request)\\nexcept PermissionDenied:\\n    print('permission denied for missing role')\")"
)"
printf '%s\n' "$decorator_denies_output"
assert_contains "$decorator_denies_output" "permission denied for missing role"

section "Verify role decorator allows users with role"
decorator_allows_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.http import HttpResponse; from django.test import RequestFactory; from apps.roles.models import Role; from apps.roles.permissions import role_required; User=get_user_model(); user=User.objects.get(email='$VERIFY_USER_EMAIL'); role=Role.objects.get(slug='$VERIFY_ROLE_SLUG'); role.users.add(user); request=RequestFactory().get('/protected/'); request.user=user; protected=role_required('$VERIFY_ROLE_SLUG')(lambda request: HttpResponse('allowed')); response=protected(request); print(response.status_code); print(response.content.decode())"
)"
printf '%s\n' "$decorator_allows_output"
assert_contains "$decorator_allows_output" "200"
assert_contains "$decorator_allows_output" "allowed"

section "Verify migrations remain clean and applied"
makemigrations_output="$(
    capture docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local
)"
printf '%s\n' "$makemigrations_output"
assert_contains "$makemigrations_output" "No changes detected"

migrate_output="$(capture docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local)"
printf '%s\n' "$migrate_output"
assert_contains "$migrate_output" "No migrations to apply"

section "Verify dashboard tests"
dashboard_tests_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --reuse-db apps/dashboard/tests/test_dashboard_views.py -q
)"
printf '%s\n' "$dashboard_tests_output"
assert_contains "$dashboard_tests_output" "passed"

section "Verify role and permission tests"
role_tests_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --reuse-db apps/roles -q
)"
printf '%s\n' "$role_tests_output"
assert_contains "$role_tests_output" "passed"

section "Verify top-level integration view tests"
view_tests_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --reuse-db tests/test_views.py -q
)"
printf '%s\n' "$view_tests_output"
assert_contains "$view_tests_output" "6 passed"

section "Verify full isolated test collection"
collect_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --collect-only -q
)"
printf '%s\n' "$collect_output"
assert_contains "$collect_output" "apps/dashboard/tests/test_dashboard_views.py::test_dashboard_redirects_anonymous_users"
assert_contains "$collect_output" "apps/dashboard/tests/test_dashboard_views.py::test_dashboard_displays_roles_from_view_context"
assert_contains "$collect_output" "apps/roles/tests/test_models.py::test_user_has_role_uses_studybuddy_roles_relation"
assert_contains "$collect_output" "apps/roles/tests/test_models.py::test_role_required_allows_users_with_required_role"
assert_contains "$collect_output" "apps/roles/tests/test_models.py::test_role_required_denies_users_without_required_role"
assert_contains "$collect_output" "tests collected"

section "Verify formatting and linting"
black_output="$(capture docker compose exec -T web python -m black . --check)"
printf '%s\n' "$black_output"
assert_contains "$black_output" "left unchanged"

ruff_output="$(capture docker compose exec -T web python -m ruff check .)"
printf '%s\n' "$ruff_output"
assert_contains "$ruff_output" "All checks passed"

isort_output="$(capture docker compose exec -T web python -m isort . --check-only)"
printf '%s\n' "$isort_output"

section "Verify full isolated test suite"
pytest_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --reuse-db -q
)"
printf '%s\n' "$pytest_output"
assert_contains "$pytest_output" "passed"

section "Clean up Friday verification data"
final_cleanup_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from apps.roles.models import Role; User=get_user_model(); User.objects.filter(email__in=['$VERIFY_USER_EMAIL','$VERIFY_ADMIN_EMAIL']).delete(); Role.objects.filter(slug='$VERIFY_ROLE_SLUG').delete(); print('Friday verification data cleaned up')"
)"
printf '%s\n' "$final_cleanup_output"
assert_contains "$final_cleanup_output" "Friday verification data cleaned up"

section "Final Friday receipt"
final_check_output="$(capture docker compose exec -T web python manage.py check --settings=config.settings.local)"
printf '%s\n' "$final_check_output"
assert_contains "$final_check_output" "System check identified no issues"

final_makemigrations_output="$(
    capture docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local
)"
printf '%s\n' "$final_makemigrations_output"
assert_contains "$final_makemigrations_output" "No changes detected"

cat <<'RECEIPT'

Sprint 1 Day 5 verification complete.

Verified:
- Dashboard route resolves.
- Dashboard template is discoverable.
- Anonymous users are redirected away from the dashboard.
- Authenticated users can view the dashboard.
- Dashboard is the post-login product surface.
- Authenticated navigation includes Dashboard, Profile, and Log Out.
- Public navigation includes Log In and Create Account.
- Role permission helpers import successfully.
- Anonymous users fail role checks.
- Superusers pass role checks.
- Users without roles fail role checks.
- Users with roles pass role checks.
- The role decorator blocks missing roles.
- The role decorator allows matching roles.
- Migrations remain clean and applied.
- Black, Ruff, and isort pass.
- The pytest suite passes.
- Sprint 1 remains compatible with the current Sprint 2 project state.

RECEIPT
