"""Settings tests for the StudyBuddy Django project."""

from __future__ import annotations

import os
import subprocess
import sys


def read_test_database_setting(setting_name: str, env: dict[str, str]) -> str:
    """Return one test database setting from an isolated Python process."""
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import config.settings.test as settings; "
                f"print(settings.DATABASES['default']['{setting_name}'])"
            ),
        ],
        check=True,
        capture_output=True,
        env=env,
        text=True,
    )
    return result.stdout.strip()


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
