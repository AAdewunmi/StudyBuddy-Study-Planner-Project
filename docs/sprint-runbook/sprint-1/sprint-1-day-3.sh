#!/usr/bin/env bash
#
# Sprint 1 Day 3 Console-Only Verification Runbook
#
# Purpose:
#   Verify the StudyBuddy custom user model, roles foundation, identity
#   factories, admin registration, and PostgreSQL-backed test workflow for
#   Sprint 1 Wednesday.
#
# Execution instructions:
#   1. Run this file from anywhere inside the repository:
#
#        ./docs/sprint-runbook/sprint-1/sprint-1-day-3.sh
#
#   2. If the file is not executable, run:
#
#        chmod +x docs/sprint-runbook/sprint-1/sprint-1-day-3.sh
#
#   3. Docker Desktop or a compatible Docker daemon must be running.
#   4. The script builds/recreates the Docker Compose web container so checks
#      run against the same source and dependency environment as the app.
#
# Expected final receipt:
#   - Custom user model is active.
#   - AUTH_USER_MODEL points to users.CustomUser.
#   - Role model is registered and persisted.
#   - Roles are assigned through Role.users and user.studybuddy_roles.
#   - Users can be created through the custom manager.
#   - Duplicate user emails are rejected.
#   - Duplicate role slugs are rejected.
#   - Migrations are clean and applied.
#   - Black, Ruff, and the isolated pytest suite pass.

set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
EXPECTED_ROOT_NAME="StudyBuddy-Study-Planner-Project"
VERIFY_EMAIL="wednesday.user@example.com"
VERIFY_ROLE_SLUG="learner"

section() {
    printf '\n==> %s\n' "$1"
}

run() {
    printf '\n$ %s\n' "$*"
    "$@"
}

capture() {
    printf '\n$ %s\n' "$*" >&2
    "$@"
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

section "Verify repository root"
run cd "$PROJECT_ROOT"
printf 'Repository root: %s\n' "$PROJECT_ROOT"

if [[ "$(basename "$PROJECT_ROOT")" != "$EXPECTED_ROOT_NAME" ]]; then
    printf 'Expected repository directory to end with: %s\n' "$EXPECTED_ROOT_NAME" >&2
    printf 'Actual repository directory: %s\n' "$(basename "$PROJECT_ROOT")" >&2
    exit 1
fi

section "Verify required Wednesday identity files"
required_files=(
    "apps/users/models.py"
    "apps/users/admin.py"
    "apps/users/apps.py"
    "apps/users/factories.py"
    "apps/users/tests/test_models.py"
    "apps/roles/models.py"
    "apps/roles/admin.py"
    "apps/roles/apps.py"
    "apps/roles/factories.py"
    "apps/roles/tests/test_models.py"
    "tests/test_models.py"
    "pytest.ini"
    "docker-compose.yml"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
        printf 'Missing required file: %s\n' "$file" >&2
        exit 1
    fi
    printf 'OK: %s\n' "$file"
done

section "Start Docker/PostgreSQL stack"
run docker compose up -d --build

compose_status="$(capture docker compose ps)"
printf '%s\n' "$compose_status"
assert_contains "$compose_status" "db"
assert_contains "$compose_status" "web"

section "Verify Django settings and app registration"
run docker compose exec -T web python manage.py check --settings=config.settings.local

auth_user_model="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.conf import settings; print(f'AUTH_USER_MODEL={settings.AUTH_USER_MODEL}')" \
    | tail -n 1
)"
printf '%s\n' "$auth_user_model"
[[ "$auth_user_model" == "AUTH_USER_MODEL=users.CustomUser" ]]

registered_models="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.apps import apps; print(apps.get_model('users', 'CustomUser')); print(apps.get_model('roles', 'Role'))"
)"
printf '%s\n' "$registered_models"
assert_contains "$registered_models" "<class 'apps.users.models.CustomUser'>"
assert_contains "$registered_models" "<class 'apps.roles.models.Role'>"

section "Verify migrations are clean and applied"
makemigrations_output="$(capture docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local)"
printf '%s\n' "$makemigrations_output"
assert_contains "$makemigrations_output" "No changes detected"

migrate_output="$(capture docker compose exec -T web python manage.py migrate --noinput --settings=config.settings.local)"
printf '%s\n' "$migrate_output"
assert_contains "$migrate_output" "Operations to perform:"

showmigrations_output="$(capture docker compose exec -T web python manage.py showmigrations users roles --settings=config.settings.local)"
printf '%s\n' "$showmigrations_output"
assert_contains "$showmigrations_output" "roles"
assert_contains "$showmigrations_output" "[X] 0001_initial"
assert_contains "$showmigrations_output" "[X] 0002_initial"
assert_contains "$showmigrations_output" "[X] 0003_rename_role_name_and_add_timestamps"
assert_contains "$showmigrations_output" "users"
assert_contains "$showmigrations_output" "[X] 0002_alter_customuser_options_alter_customuser_managers_and_more"

section "Verify database tables for users and roles"
tables_output="$(capture docker compose exec -T db psql -U studybuddy -d studybuddy_local -tAc "\dt public.*")"
printf '%s\n' "$tables_output"
assert_contains "$tables_output" "public|roles_role|table|studybuddy"
assert_contains "$tables_output" "public|roles_role_users|table|studybuddy"
assert_contains "$tables_output" "public|users_customuser|table|studybuddy"
assert_contains "$tables_output" "public|users_customuser_groups|table|studybuddy"
assert_contains "$tables_output" "public|users_customuser_user_permissions|table|studybuddy"

migration_records="$(
    capture docker compose exec -T db psql -U studybuddy -d studybuddy_local -tAc \
        "SELECT app, name FROM django_migrations WHERE app IN ('users', 'roles') ORDER BY app, name;"
)"
printf '%s\n' "$migration_records"
assert_contains "$migration_records" "roles|0001_initial"
assert_contains "$migration_records" "roles|0002_initial"
assert_contains "$migration_records" "roles|0003_rename_role_name_and_add_timestamps"
assert_contains "$migration_records" "users|0001_initial"
assert_contains "$migration_records" "users|0002_alter_customuser_options_alter_customuser_managers_and_more"

section "Verify custom user model fields"
user_model_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; User=get_user_model(); print(User.USERNAME_FIELD); print([field.name for field in User._meta.fields]); print([field.name for field in User._meta.many_to_many])"
)"
printf '%s\n' "$user_model_output"
assert_contains "$user_model_output" "email"
assert_contains "$user_model_output" "username"
assert_contains "$user_model_output" "password"
assert_contains "$user_model_output" "groups"
assert_contains "$user_model_output" "user_permissions"

role_accessor="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from apps.roles.models import Role; print(Role._meta.get_field('users').remote_field.get_accessor_name())" \
    | tail -n 1
)"
printf 'role_user_accessor=%s\n' "$role_accessor"
[[ "$role_accessor" == "studybuddy_roles" ]]

section "Verify role model fields"
role_model_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from apps.roles.models import Role; print([field.name for field in Role._meta.fields]); print(Role._meta.ordering)"
)"
printf '%s\n' "$role_model_output"
assert_contains "$role_model_output" "slug"
assert_contains "$role_model_output" "display_name"
assert_contains "$role_model_output" "description"
assert_contains "$role_model_output" "created_at"
assert_contains "$role_model_output" "updated_at"
assert_contains "$role_model_output" "('display_name',)"

section "Clean any previous Wednesday verification data"
run docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
    "from django.contrib.auth import get_user_model; from apps.roles.models import Role; User=get_user_model(); User.objects.filter(email='$VERIFY_EMAIL').delete(); Role.objects.filter(slug='$VERIFY_ROLE_SLUG').delete(); print('previous Wednesday verification data removed')"

section "Verify user creation through the custom manager"
user_creation_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; User=get_user_model(); user=User.objects.create_user(email='$VERIFY_EMAIL', password='StrongPassword123!'); print(user.email); print(user.username); print(user.check_password('StrongPassword123!'))"
)"
printf '%s\n' "$user_creation_output"
assert_contains "$user_creation_output" "$VERIFY_EMAIL"
assert_contains "$user_creation_output" "True"

username_line="$(printf '%s\n' "$user_creation_output" | awk 'NF { lines[++count] = $0 } END { print lines[count - 1] }')"
if [[ -z "$username_line" ]]; then
    printf 'Expected generated username to be non-empty.\n' >&2
    exit 1
fi

section "Verify role persistence"
role_creation_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from apps.roles.models import Role; role=Role.objects.create(slug='$VERIFY_ROLE_SLUG', display_name='Learner', description='Standard StudyBuddy learner role.'); print(role.slug); print(role.display_name); print(str(role))"
)"
printf '%s\n' "$role_creation_output"
assert_contains "$role_creation_output" "$VERIFY_ROLE_SLUG"
assert_contains "$role_creation_output" "Learner"

section "Verify user-role assignment through Role.users and user.studybuddy_roles"
assignment_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        "from django.contrib.auth import get_user_model; from apps.roles.models import Role; User=get_user_model(); user=User.objects.get(email='$VERIFY_EMAIL'); role=Role.objects.get(slug='$VERIFY_ROLE_SLUG'); role.users.add(user); print(user.studybuddy_roles.filter(slug='$VERIFY_ROLE_SLUG').exists()); print(role.users.filter(email='$VERIFY_EMAIL').exists())"
)"
printf '%s\n' "$assignment_output"
assert_contains "$assignment_output" "True"

section "Verify uniqueness constraints"
duplicate_user_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        $'from django.contrib.auth import get_user_model\nfrom django.db import IntegrityError, transaction\nUser = get_user_model()\nprint("before duplicate user check")\nUser.objects.get(email="'"$VERIFY_EMAIL"$'")\ntry:\n    with transaction.atomic():\n        User.objects.create_user(email="'"$VERIFY_EMAIL"$'", password="StrongPassword123!")\nexcept IntegrityError:\n    print("duplicate email rejected")'
)"
printf '%s\n' "$duplicate_user_output"
assert_contains "$duplicate_user_output" "before duplicate user check"
assert_contains "$duplicate_user_output" "duplicate email rejected"

duplicate_role_output="$(
    capture docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
        $'from apps.roles.models import Role\nfrom django.db import IntegrityError, transaction\nprint("before duplicate role check")\nRole.objects.get(slug="'"$VERIFY_ROLE_SLUG"$'")\ntry:\n    with transaction.atomic():\n        Role.objects.create(slug="'"$VERIFY_ROLE_SLUG"$'", display_name="Learner Duplicate")\nexcept IntegrityError:\n    print("duplicate role slug rejected")'
)"
printf '%s\n' "$duplicate_role_output"
assert_contains "$duplicate_role_output" "before duplicate role check"
assert_contains "$duplicate_role_output" "duplicate role slug rejected"

section "Verify admin registration imports"
run docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
    "import apps.users.admin; import apps.roles.admin; print('admin imports OK')"

section "Verify identity factories and model tests"
identity_tests_output="$(capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest apps/users/tests/test_models.py apps/roles/tests/test_models.py -q)"
printf '%s\n' "$identity_tests_output"
assert_contains "$identity_tests_output" "passed"

section "Verify formatting, linting, and full isolated test suite"
run docker compose exec -T web python -m black . --check
run docker compose exec -T web python -m ruff check .

pytest_output="$(capture docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q)"
printf '%s\n' "$pytest_output"
assert_contains "$pytest_output" "passed"

section "Clean up verification data"
run docker compose exec -T web python manage.py shell --settings=config.settings.local -c \
    "from django.contrib.auth import get_user_model; from apps.roles.models import Role; User=get_user_model(); User.objects.filter(email='$VERIFY_EMAIL').delete(); Role.objects.filter(slug='$VERIFY_ROLE_SLUG').delete(); print('Wednesday verification data cleaned up')"

section "Final Wednesday receipt"
run docker compose exec -T web python manage.py check --settings=config.settings.local
run docker compose exec -T web python manage.py makemigrations --check --dry-run --settings=config.settings.local
run docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest -q

printf '\nCustom user model is active.\n'
printf 'AUTH_USER_MODEL points to users.CustomUser.\n'
printf 'Role model is registered and persisted.\n'
printf 'Users can be created through the custom manager.\n'
printf 'Users can be assigned roles through user.studybuddy_roles.\n'
printf 'Duplicate user emails are rejected.\n'
printf 'Duplicate role slugs are rejected.\n'
printf 'Migrations are clean and applied.\n'
printf 'Black and Ruff pass.\n'
printf 'The isolated pytest suite passes.\n'
printf 'Sprint 1 Day 3 verification complete.\n'
