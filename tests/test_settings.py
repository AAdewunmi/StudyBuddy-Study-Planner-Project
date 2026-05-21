"""Settings tests for the StudyBuddy Django project."""

from __future__ import annotations

import os
import subprocess
import sys


def run_settings_snippet(
    snippet: str,
    env_overrides: dict[str, str],
    *,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    """Run a settings snippet in an isolated Python process."""

    env = os.environ.copy()
    env.update(env_overrides)

    return subprocess.run(
        [sys.executable, "-c", snippet],
        check=check,
        capture_output=True,
        env=env,
        text=True,
    )


def read_test_database_setting(setting_name: str, env: dict[str, str]) -> str:
    """Return one test database setting from an isolated Python process."""
    result = run_settings_snippet(
        (
            "import config.settings.test as settings; "
            f"print(settings.DATABASES['default']['{setting_name}'])"
        ),
        env,
    )
    return result.stdout.strip()


def production_env(**overrides: str) -> dict[str, str]:
    """Return a complete production-like environment for settings imports."""

    env = {
        "DJANGO_SECRET_KEY": "prod-secret",
        "DJANGO_ALLOWED_HOSTS": "example.com,www.example.com",
        "DJANGO_CSRF_TRUSTED_ORIGINS": "https://example.com",
        "DATABASE_URL": "postgres://studybuddy:studybuddy@db:5432/studybuddy_local",
        "DJANGO_EMAIL_BACKEND": "django.core.mail.backends.smtp.EmailBackend",
        "DJANGO_DEFAULT_FROM_EMAIL": "StudyBuddy <noreply@example.com>",
        "DJANGO_EMAIL_HOST": "smtp.example.com",
        "DJANGO_EMAIL_PORT": "587",
        "DJANGO_EMAIL_USE_TLS": "true",
        "DJANGO_EMAIL_USE_SSL": "false",
        "DJANGO_EMAIL_TIMEOUT": "10",
    }
    env.update(overrides)
    return env


def test_test_settings_use_postgres_database_name_without_database_url() -> None:
    """Test settings keep PostgreSQL and override only the fallback name."""
    env = os.environ.copy()
    env["DATABASE_URL"] = ""
    env["TEST_DATABASE_URL"] = ""
    env["POSTGRES_DB"] = "studybuddy_test"
    env["RUNNING_IN_DOCKER"] = "False"

    assert read_test_database_setting("ENGINE", env) == "django.db.backends.postgresql"
    assert read_test_database_setting("NAME", env) == "studybuddy_test"


def test_test_settings_use_explicit_test_database_url() -> None:
    """A dedicated test database URL can override the app database URL."""
    env = os.environ.copy()
    env["DATABASE_URL"] = "postgres://studybuddy:studybuddy@db:5432/studybuddy_local"
    env["TEST_DATABASE_URL"] = (
        "postgres://studybuddy:studybuddy@localhost:5432/studybuddy_test"
    )
    env["RUNNING_IN_DOCKER"] = "False"

    assert read_test_database_setting("HOST", env) == "localhost"
    assert read_test_database_setting("NAME", env) == "studybuddy_test"


def test_test_settings_map_docker_db_host_for_host_side_tests() -> None:
    """Host-side pytest can use a Docker Compose database URL from .env."""
    env = os.environ.copy()
    env["DATABASE_URL"] = "postgres://studybuddy:studybuddy@db:5432/studybuddy_local"
    env["TEST_DATABASE_URL"] = ""
    env["RUNNING_IN_DOCKER"] = "False"

    assert read_test_database_setting("HOST", env) == "localhost"


def test_test_settings_keep_docker_db_host_inside_container() -> None:
    """Container-side pytest keeps Docker Compose service discovery intact."""
    env = os.environ.copy()
    env["DATABASE_URL"] = "postgres://studybuddy:studybuddy@db:5432/studybuddy_local"
    env["TEST_DATABASE_URL"] = ""
    env["RUNNING_IN_DOCKER"] = "True"

    assert read_test_database_setting("HOST", env) == "db"


def test_base_env_bool_parses_explicit_truthy_values() -> None:
    """Base settings expose a small predictable set of truthy values."""
    result = run_settings_snippet(
        (
            "from config.settings.base import env_bool; "
            "print(env_bool('FEATURE_ONE')); "
            "print(env_bool('FEATURE_TWO')); "
            "print(env_bool('FEATURE_THREE')); "
            "print(env_bool('FEATURE_FOUR'))"
        ),
        {
            "FEATURE_ONE": "1",
            "FEATURE_TWO": "true",
            "FEATURE_THREE": "YES",
            "FEATURE_FOUR": "on",
        },
    )

    assert result.stdout.splitlines() == ["True", "True", "True", "True"]


def test_base_env_bool_uses_default_for_missing_value() -> None:
    """Missing boolean environment values fall back to the provided default."""
    result = run_settings_snippet(
        (
            "from config.settings.base import env_bool; "
            "print(env_bool('MISSING_FLAG', True))"
        ),
        {},
    )

    assert result.stdout.strip() == "True"


def test_base_env_list_cleans_comma_separated_values() -> None:
    """Base settings clean comma-separated list environment variables."""
    result = run_settings_snippet(
        "from config.settings.base import env_list; print(env_list('SAMPLE_LIST'))",
        {"SAMPLE_LIST": " alpha, beta ,, gamma "},
    )

    assert result.stdout.strip() == "['alpha', 'beta', 'gamma']"


def test_base_env_list_uses_default_for_missing_value() -> None:
    """Missing list environment values fall back to a copied default list."""
    result = run_settings_snippet(
        (
            "from config.settings.base import env_list; "
            "print(env_list('MISSING_LIST', ['local']))"
        ),
        {},
    )

    assert result.stdout.strip() == "['local']"


def test_base_settings_expose_release_sha_from_environment() -> None:
    """Release metadata can be injected by the deployment platform."""
    result = run_settings_snippet(
        "import config.settings.base as settings; print(settings.RELEASE_SHA)",
        {"RELEASE_SHA": "abc123"},
    )

    assert result.stdout.strip() == "abc123"


def test_base_settings_use_render_git_commit_as_release_sha() -> None:
    """Render commit metadata identifies the deployed revision."""
    result = run_settings_snippet(
        "import config.settings.base as settings; print(settings.RELEASE_SHA)",
        {"RELEASE_SHA": "", "RENDER_GIT_COMMIT": "render-commit-abc123"},
    )

    assert result.stdout.strip() == "render-commit-abc123"


def test_production_settings_import_with_required_environment() -> None:
    """Production settings import when the deployment environment is complete."""
    result = run_settings_snippet(
        (
            "import config.settings.production as settings; "
            "print(settings.DEBUG); "
            "print(settings.ALLOWED_HOSTS); "
            "print(settings.DATABASES['default']['CONN_MAX_AGE']); "
            "print(settings.SECURE_SSL_REDIRECT); "
            "print(settings.EMAIL_BACKEND); "
            "print(settings.EMAIL_HOST); "
            "print(settings.EMAIL_PORT); "
            "print(settings.DEFAULT_FROM_EMAIL)"
        ),
        production_env(),
    )

    assert result.stdout.splitlines() == [
        "False",
        "['example.com', 'www.example.com']",
        "600",
        "True",
        "django.core.mail.backends.smtp.EmailBackend",
        "smtp.example.com",
        "587",
        "StudyBuddy <noreply@example.com>",
    ]


def test_production_settings_require_secret_key() -> None:
    """Production settings fail fast without a secret key."""
    result = run_settings_snippet(
        "import config.settings.production",
        production_env(DJANGO_SECRET_KEY=""),
        check=False,
    )

    assert result.returncode != 0
    assert "DJANGO_SECRET_KEY must be set in production." in result.stderr


def test_production_settings_require_allowed_hosts() -> None:
    """Production settings fail fast without allowed hosts."""
    result = run_settings_snippet(
        "import config.settings.production",
        production_env(DJANGO_ALLOWED_HOSTS=""),
        check=False,
    )

    assert result.returncode != 0
    assert "DJANGO_ALLOWED_HOSTS must be set in production." in result.stderr


def test_production_settings_require_database_url() -> None:
    """Production settings fail fast without a database URL."""
    result = run_settings_snippet(
        "import config.settings.production",
        production_env(DATABASE_URL=""),
        check=False,
    )

    assert result.returncode != 0
    assert "DATABASE_URL must be set in production." in result.stderr


def test_production_settings_require_default_from_email() -> None:
    """Production settings fail fast without a sender address."""
    result = run_settings_snippet(
        "import config.settings.production",
        production_env(DJANGO_DEFAULT_FROM_EMAIL=""),
        check=False,
    )

    assert result.returncode != 0
    assert "DJANGO_DEFAULT_FROM_EMAIL must be set in production." in result.stderr


def test_production_settings_require_smtp_host_by_default() -> None:
    """Production SMTP email requires an explicit provider host."""
    result = run_settings_snippet(
        "import config.settings.production",
        production_env(DJANGO_EMAIL_HOST=""),
        check=False,
    )

    assert result.returncode != 0
    assert "DJANGO_EMAIL_HOST must be set in production." in result.stderr


def test_production_settings_reject_conflicting_email_security_flags() -> None:
    """SMTP email cannot use TLS and SSL modes at the same time."""
    result = run_settings_snippet(
        "import config.settings.production",
        production_env(DJANGO_EMAIL_USE_TLS="true", DJANGO_EMAIL_USE_SSL="true"),
        check=False,
    )

    assert result.returncode != 0
    assert (
        "DJANGO_EMAIL_USE_TLS and DJANGO_EMAIL_USE_SSL cannot both be true."
        in result.stderr
    )


def test_production_settings_require_database_ssl_by_default() -> None:
    """Production database connections require SSL unless explicitly disabled."""
    result = run_settings_snippet(
        (
            "import config.settings.production as settings; "
            "print(settings.DATABASES['default']['OPTIONS']['sslmode'])"
        ),
        production_env(),
    )

    assert result.stdout.strip() == "require"


def test_production_settings_allow_disabling_database_ssl_for_local_checks() -> None:
    """Local production-settings smoke checks can disable database SSL."""
    result = run_settings_snippet(
        (
            "import config.settings.production as settings; "
            "options = settings.DATABASES['default'].get('OPTIONS', {}); "
            "print(options.get('sslmode', 'off'))"
        ),
        production_env(DATABASE_SSL_REQUIRE="False"),
    )

    assert result.stdout.strip() == "off"
