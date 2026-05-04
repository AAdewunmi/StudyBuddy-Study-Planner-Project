"""Test settings for the StudyBuddy project."""

from __future__ import annotations

from config.settings.local import *  # noqa: F403
from config.settings.local import BASE_DIR
from config.settings.local import MIDDLEWARE as BASE_MIDDLEWARE

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "test.sqlite3",
    }
}

PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]

MIDDLEWARE = [
    middleware
    for middleware in BASE_MIDDLEWARE
    if middleware != "whitenoise.middleware.WhiteNoiseMiddleware"
]
