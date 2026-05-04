"""Settings tests for the StudyBuddy Django project."""

from __future__ import annotations

import os
import subprocess
import sys


def test_test_settings_use_test_database_name_without_database_url() -> None:
    """Test settings keep the shared DB shape and override only the fallback name."""
    env = os.environ.copy()
    env["DATABASE_URL"] = ""
    env["POSTGRES_DB"] = "studybuddy_test"

    result = subprocess.run(
        [
            sys.executable,
            "-c",
            (
                "import config.settings.test as settings; "
                "print(settings.DATABASES['default']['NAME'])"
            ),
        ],
        check=True,
        capture_output=True,
        env=env,
        text=True,
    )

    assert result.stdout.strip() == "studybuddy_test"
