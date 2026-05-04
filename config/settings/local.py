"""Local development settings for StudyBuddy."""

from __future__ import annotations

from config.settings.base import *  # noqa: F403
from config.settings.base import env

DEBUG = env.bool("DJANGO_DEBUG", default=True)

ALLOWED_HOSTS = env.list(
    "DJANGO_ALLOWED_HOSTS",
    default=["localhost", "127.0.0.1"],
)

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

INTERNAL_IPS = [
    "127.0.0.1",
]
