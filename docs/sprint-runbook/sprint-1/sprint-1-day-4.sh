#!/usr/bin/env bash
#
# Sprint 1 Day 4 Console-Only Verification Runbook
#
# Purpose:
#   Verify the StudyBuddy signup, login, logout, profile, and dashboard
#   authentication journey using the current Docker + PostgreSQL workflow.
#
# Execution command:
#
#   ./docs/sprint-runbook/sprint-1/sprint-1-day-4.sh
#
# If the file is not executable, run:
#
#   chmod +x docs/sprint-runbook/sprint-1/sprint-1-day-4.sh
#
# Notes:
#   - Run from anywhere inside the repository.
#   - Docker Desktop or a compatible Docker daemon must be running.
#   - This project copies source into the Docker image, so the script rebuilds
#     the web service before verification.
#   - Current expected isolated pytest baseline: 40 tests collected/passing.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_ROOT_NAME="StudyBuddy-Study-Planner-Project"
SIGNUP_EMAIL="thursday.user@example.com"
LOGIN_EMAIL="thursday.login@example.com"
EXPECTED_TEST_COUNT=40

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

section "Verify required Thursday authentication files"
required_files=(
    "apps/users/forms.py"
    "apps/users/views.py"
    "apps/users/urls.py"
    "apps/users/tests/test_auth_views.py"
    "config/urls.py"
    "static/css/theme.css"
    "templates/base.html"
    "templates/users/signup.html"
    "templates/users/login.html"
    "templates/users/profile.html"
    "templates/dashboard/index.html"
    "tests/test_views.py"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        printf 'Missing required file: %s\n' "$file" >&2
        exit 1
    fi

    printf 'OK: %s\n' "$file"
done

section "Verify obsolete registration templates are absent"
assert_not_exists "templates/registration/login.html"
assert_not_exists "templates/registration/signup.html"

section "Start Docker/PostgreSQL stack"
run docker compose up -d --build
run docker compose ps

section "Verify Django settings and URL configuration"
check_output="$(capture docker compose exec -T web python manage.py check --settings=config.settings.local)"
printf '%s\n' "$check_output"
assert_contains "$check_output" "System check identified no issues"

url_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.urls import reverse; print(reverse('home')); print(reverse('users:signup')); print(reverse('users:login')); print(reverse('users:logout')); print(reverse('users:profile')); print(reverse('dashboard:index'))"
)"
printf '%s\n' "$url_output"
assert_contains "$url_output" "/"
assert_contains "$url_output" "/accounts/signup/"
assert_contains "$url_output" "/accounts/login/"
assert_contains "$url_output" "/accounts/logout/"
assert_contains "$url_output" "/accounts/profile/"
assert_contains "$url_output" "/dashboard/"

settings_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.conf import settings; print(settings.LOGIN_URL); print(settings.LOGIN_REDIRECT_URL); print(settings.LOGOUT_REDIRECT_URL); print(settings.AUTH_USER_MODEL)"
)"
printf '%s\n' "$settings_output"
assert_contains "$settings_output" "users:login"
assert_contains "$settings_output" "dashboard:index"
assert_contains "$settings_output" "home"
assert_contains "$settings_output" "users.CustomUser"

section "Verify templates can be discovered"
template_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.template.loader import get_template; templates=['base.html','home.html','dashboard/index.html','users/signup.html','users/login.html','users/profile.html']; [print(f'template OK: {name}') for name in templates if get_template(name)]"
)"
printf '%s\n' "$template_output"
assert_contains "$template_output" "template OK: base.html"
assert_contains "$template_output" "template OK: home.html"
assert_contains "$template_output" "template OK: dashboard/index.html"
assert_contains "$template_output" "template OK: users/signup.html"
assert_contains "$template_output" "template OK: users/login.html"
assert_contains "$template_output" "template OK: users/profile.html"

section "Verify static CSS exists inside the container"
run docker compose exec -T web test -f static/css/theme.css
printf 'container static CSS OK: static/css/theme.css\n'

section "Verify migrations remain clean and applied"
makemigrations_output="$(
    capture docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local
)"
printf '%s\n' "$makemigrations_output"
assert_contains "$makemigrations_output" "No changes detected"

migrate_output="$(capture docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local)"
printf '%s\n' "$migrate_output"
assert_contains "$migrate_output" "No migrations to apply"

section "Clean previous Thursday verification data"
cleanup_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; User=get_user_model(); User.objects.filter(email__in=['$SIGNUP_EMAIL','$LOGIN_EMAIL']).delete(); print('previous Thursday verification data removed')"
)"
printf '%s\n' "$cleanup_output"
assert_contains "$cleanup_output" "previous Thursday verification data removed"

section "Verify signup page renders"
signup_page_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.test import Client; from django.urls import reverse; client=Client(HTTP_HOST='localhost'); response=client.get(reverse('users:signup')); body=response.content.decode(); print(f'signup_status={response.status_code}'); print('Create your StudyBuddy account' in body); print('site-footer' in body)"
)"
printf '%s\n' "$signup_page_output"
assert_contains "$signup_page_output" "signup_status=200"
assert_contains "$signup_page_output" "True"

section "Verify login page renders"
login_page_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.test import Client; from django.urls import reverse; client=Client(HTTP_HOST='localhost'); response=client.get(reverse('users:login')); body=response.content.decode(); print(f'login_status={response.status_code}'); print('Log In' in body); print('site-footer' in body)"
)"
printf '%s\n' "$login_page_output"
assert_contains "$login_page_output" "login_status=200"
assert_contains "$login_page_output" "True"

section "Verify signup creates a user and reaches dashboard"
signup_post_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); User.objects.filter(email='$SIGNUP_EMAIL').delete(); client=Client(HTTP_HOST='localhost'); response=client.post(reverse('users:signup'), {'email':'$SIGNUP_EMAIL','username':'','first_name':'Thursday','last_name':'User','password1':'StrongPassword123!','password2':'StrongPassword123!'}, follow=True); print(f'signup_final_status={response.status_code}'); print(f'signup_redirect_chain={response.redirect_chain}'); print(f'user_exists={User.objects.filter(email=\"$SIGNUP_EMAIL\").exists()}'); print('Dashboard' in response.content.decode())"
)"
printf '%s\n' "$signup_post_output"
assert_contains "$signup_post_output" "signup_final_status=200"
assert_contains "$signup_post_output" "/dashboard/"
assert_contains "$signup_post_output" "user_exists=True"
assert_contains "$signup_post_output" "True"

section "Verify duplicate email signup is rejected"
duplicate_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); client=Client(HTTP_HOST='localhost'); response=client.post(reverse('users:signup'), {'email':'$SIGNUP_EMAIL','username':'duplicate-thursday','first_name':'Duplicate','last_name':'User','password1':'StrongPassword123!','password2':'StrongPassword123!'}); body=response.content.decode().lower(); print(f'duplicate_signup_status={response.status_code}'); print(f'user_count={User.objects.filter(email=\"$SIGNUP_EMAIL\").count()}'); print('already' in body or 'exists' in body)"
)"
printf '%s\n' "$duplicate_output"
assert_contains "$duplicate_output" "duplicate_signup_status=200"
assert_contains "$duplicate_output" "user_count=1"
assert_contains "$duplicate_output" "True"

section "Verify login works with email and password"
login_post_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); User.objects.filter(email='$LOGIN_EMAIL').delete(); User.objects.create_user(email='$LOGIN_EMAIL', password='StrongPassword123!'); client=Client(HTTP_HOST='localhost'); response=client.post(reverse('users:login'), {'username':'$LOGIN_EMAIL','password':'StrongPassword123!'}, follow=True); print(f'login_final_status={response.status_code}'); print(f'login_redirect_chain={response.redirect_chain}'); print('Dashboard' in response.content.decode())"
)"
printf '%s\n' "$login_post_output"
assert_contains "$login_post_output" "login_final_status=200"
assert_contains "$login_post_output" "/dashboard/"
assert_contains "$login_post_output" "True"

section "Verify invalid login fails safely"
invalid_login_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.test import Client; from django.urls import reverse; client=Client(HTTP_HOST='localhost'); response=client.post(reverse('users:login'), {'username':'$LOGIN_EMAIL','password':'WrongPassword123!'}); body=response.content.decode().lower(); print(f'invalid_login_status={response.status_code}'); print('error' in body or 'password' in body or 'valid' in body)"
)"
printf '%s\n' "$invalid_login_output"
assert_contains "$invalid_login_output" "invalid_login_status=200"
assert_contains "$invalid_login_output" "True"

section "Verify profile requires authentication"
anonymous_profile_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.test import Client; from django.urls import reverse; client=Client(HTTP_HOST='localhost'); response=client.get(reverse('users:profile')); print(f'anonymous_profile_status={response.status_code}'); print(f'anonymous_profile_redirect={response.headers.get(\"Location\")}')"
)"
printf '%s\n' "$anonymous_profile_output"
assert_contains "$anonymous_profile_output" "anonymous_profile_status=302"
assert_contains "$anonymous_profile_output" "/accounts/login/?next=/accounts/profile/"

section "Verify authenticated profile renders user identity"
profile_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); user=User.objects.get(email='$LOGIN_EMAIL'); client=Client(HTTP_HOST='localhost'); client.force_login(user); response=client.get(reverse('users:profile')); body=response.content.decode(); print(f'authenticated_profile_status={response.status_code}'); print('$LOGIN_EMAIL' in body); print('No roles assigned yet.' in body)"
)"
printf '%s\n' "$profile_output"
assert_contains "$profile_output" "authenticated_profile_status=200"
assert_contains "$profile_output" "True"

section "Verify authenticated users are redirected away from login and signup"
authenticated_public_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); user=User.objects.get(email='$LOGIN_EMAIL'); client=Client(HTTP_HOST='localhost'); client.force_login(user); login_response=client.get(reverse('users:login')); signup_response=client.get(reverse('users:signup')); print(f'authenticated_login_redirect={login_response.headers.get(\"Location\")}'); print(f'authenticated_signup_redirect={signup_response.headers.get(\"Location\")}')"
)"
printf '%s\n' "$authenticated_public_output"
assert_contains "$authenticated_public_output" "authenticated_login_redirect=/dashboard/"
assert_contains "$authenticated_public_output" "authenticated_signup_redirect=/dashboard/"

section "Verify logout redirects safely and profile is protected after logout"
logout_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from django.test import Client; from django.urls import reverse; User=get_user_model(); user=User.objects.get(email='$LOGIN_EMAIL'); client=Client(HTTP_HOST='localhost'); client.force_login(user); logout_response=client.post(reverse('users:logout')); profile_response=client.get(reverse('users:profile')); print(f'logout_status={logout_response.status_code}'); print(f'logout_redirect={logout_response.headers.get(\"Location\")}'); print(f'profile_after_logout_status={profile_response.status_code}'); print(f'profile_after_logout_redirect={profile_response.headers.get(\"Location\")}')"
)"
printf '%s\n' "$logout_output"
assert_contains "$logout_output" "logout_status=302"
assert_contains "$logout_output" "logout_redirect=/"
assert_contains "$logout_output" "profile_after_logout_status=302"
assert_contains "$logout_output" "/accounts/login/?next=/accounts/profile/"

section "Verify authentication view tests"
auth_tests_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --reuse-db apps/users/tests/test_auth_views.py -q
)"
printf '%s\n' "$auth_tests_output"
assert_contains "$auth_tests_output" "passed"

section "Verify top-level view tests"
view_tests_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --reuse-db tests/test_views.py -q
)"
printf '%s\n' "$view_tests_output"
assert_contains "$view_tests_output" "passed"

section "Verify formatting and linting"
black_output="$(capture docker compose exec -T web python -m black . --check)"
printf '%s\n' "$black_output"
assert_contains "$black_output" "left unchanged"

ruff_output="$(capture docker compose exec -T web python -m ruff check .)"
printf '%s\n' "$ruff_output"
assert_contains "$ruff_output" "All checks passed"

section "Verify isolated test suite count and pass status"
collect_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --collect-only -q
)"
printf '%s\n' "$collect_output"
assert_contains "$collect_output" "${EXPECTED_TEST_COUNT} tests collected"

pytest_output="$(
    capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --reuse-db -q
)"
printf '%s\n' "$pytest_output"
assert_contains "$pytest_output" "${EXPECTED_TEST_COUNT} passed"

section "Clean up Thursday verification data"
final_cleanup_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; User=get_user_model(); User.objects.filter(email__in=['$SIGNUP_EMAIL','$LOGIN_EMAIL']).delete(); print('Thursday verification data cleaned up')"
)"
printf '%s\n' "$final_cleanup_output"
assert_contains "$final_cleanup_output" "Thursday verification data cleaned up"

section "Final Thursday receipt"
final_check_output="$(capture docker compose exec -T web python manage.py check --settings=config.settings.local)"
printf '%s\n' "$final_check_output"
assert_contains "$final_check_output" "System check identified no issues"

final_makemigrations_output="$(
    capture docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local
)"
printf '%s\n' "$final_makemigrations_output"
assert_contains "$final_makemigrations_output" "No changes detected"

cat <<'RECEIPT'

Sprint 1 Day 4 verification complete.

Verified:
- Signup page renders.
- Login page renders.
- Signup creates a user and reaches the dashboard.
- Duplicate email signup is rejected.
- Users can log in with email and password.
- Invalid login fails safely.
- Anonymous users are redirected away from profile.
- Authenticated users can view profile identity.
- Authenticated users are redirected away from login/signup.
- Logout redirects safely.
- Logged-out users cannot access profile.
- Theme CSS is static/css/theme.css.
- Dashboard is the post-login product surface.
- Migrations remain clean and applied.
- Black and Ruff pass.
- The isolated pytest suite passes with 40 tests.

RECEIPT
