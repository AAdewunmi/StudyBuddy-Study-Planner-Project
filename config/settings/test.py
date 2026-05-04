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

if not base_settings.env("DATABASE_URL", default=None):
    DATABASES["default"]["NAME"] = base_settings.env(  # noqa: F405
        "POSTGRES_DB",
        default="studybuddy_test",
    )

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]

EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"

MIDDLEWARE = [
    middleware
    for middleware in base_settings.MIDDLEWARE
    if middleware != "whitenoise.middleware.WhiteNoiseMiddleware"
]
