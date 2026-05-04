"""Test settings for the StudyBuddy project."""

from __future__ import annotations

from config.settings import base as base_settings
from config.settings.base import *  # noqa: F403

DEBUG = False

SECRET_KEY = base_settings.env("DJANGO_SECRET_KEY", default="test-secret-key")

ALLOWED_HOSTS = base_settings.env.list(
    "DJANGO_ALLOWED_HOSTS",
    default=["localhost", "127.0.0.1", "testserver"],
)

if base_settings.env("DATABASE_URL", default=None):
    DATABASES = {
        "default": base_settings.env.db("DATABASE_URL"),
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": base_settings.env("POSTGRES_DB", default="studybuddy_test"),
            "USER": base_settings.env("POSTGRES_USER", default="studybuddy"),
            "PASSWORD": base_settings.env(
                "POSTGRES_PASSWORD",
                default="studybuddy",
            ),
            "HOST": base_settings.env("POSTGRES_HOST", default="localhost"),
            "PORT": base_settings.env("POSTGRES_PORT", default="5432"),
        }
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
