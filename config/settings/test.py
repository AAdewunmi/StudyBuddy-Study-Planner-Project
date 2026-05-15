"""Test settings for the StudyBuddy project."""

from __future__ import annotations

from pathlib import Path

from config.settings import base as base_settings
from config.settings.base import *  # noqa: F403

DEBUG = False

SECRET_KEY = base_settings.env("DJANGO_SECRET_KEY", default="test-secret-key")

ALLOWED_HOSTS = base_settings.env.list(
    "DJANGO_ALLOWED_HOSTS",
    default=["localhost", "127.0.0.1", "testserver"],
)

RUNNING_IN_DOCKER = base_settings.env.bool(
    "RUNNING_IN_DOCKER",
    default=Path("/.dockerenv").exists(),
)


def normalise_test_database_host(database_config: dict[str, str]) -> dict[str, str]:
    """Map Docker's internal database hostname for host-side pytest runs."""
    if database_config.get("HOST") == "db" and not RUNNING_IN_DOCKER:
        return {**database_config, "HOST": "localhost"}

    return database_config


def postgres_test_database_config() -> dict[str, str]:
    """Return the PostgreSQL-only test database configuration."""
    test_database_url = base_settings.env("TEST_DATABASE_URL", default=None)
    database_url = base_settings.env("DATABASE_URL", default=None)

    if test_database_url:
        return normalise_test_database_host(base_settings.env.db("TEST_DATABASE_URL"))

    if database_url:
        return normalise_test_database_host(base_settings.env.db("DATABASE_URL"))

    return normalise_test_database_host(
        {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": base_settings.env(
                "POSTGRES_DB",
                default="studybuddy_test",
            ),
            "USER": base_settings.env("POSTGRES_USER", default="studybuddy"),
            "PASSWORD": base_settings.env(
                "POSTGRES_PASSWORD",
                default="studybuddy",
            ),
            "HOST": base_settings.env("POSTGRES_HOST", default="localhost"),
            "PORT": base_settings.env("POSTGRES_PORT", default="5432"),
        }
    )


DATABASES = {
    "default": postgres_test_database_config(),
}

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]

EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"

MIDDLEWARE = [
    middleware
    for middleware in base_settings.MIDDLEWARE
    if middleware != "whitenoise.middleware.WhiteNoiseMiddleware"
]
