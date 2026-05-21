"""Production settings for the StudyBuddy SaaS MVP.

Production settings are intentionally environment-driven. Secrets, database
credentials, hostnames, CSRF origins, email provider settings, and release
metadata must be provided by the deployment platform.
"""

from __future__ import annotations

import os

from django.core.exceptions import ImproperlyConfigured

from .base import *  # noqa: F403
from .base import BASE_DIR, env, env_bool, env_list


def required_env(name: str) -> str:
    """Return a required environment variable or raise a clear error."""

    value = os.environ.get(name)
    if not value:
        raise ImproperlyConfigured(f"{name} must be set in production.")
    return value


def env_int(name: str, default: int) -> int:
    """Return an integer environment variable or raise a clear error."""

    value = os.environ.get(name, str(default))
    try:
        return int(value)
    except ValueError as exc:
        raise ImproperlyConfigured(f"{name} must be an integer.") from exc


DEBUG = False

SECRET_KEY = required_env("DJANGO_SECRET_KEY")

ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")
if not ALLOWED_HOSTS:
    raise ImproperlyConfigured("DJANGO_ALLOWED_HOSTS must be set in production.")

CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")

DATABASE_URL = required_env("DATABASE_URL")
DATABASES = {
    "default": env.db("DATABASE_URL"),
}
DATABASES["default"]["CONN_MAX_AGE"] = 600

if env_bool("DATABASE_SSL_REQUIRE", default=True):
    DATABASES["default"].setdefault("OPTIONS", {})
    DATABASES["default"]["OPTIONS"]["sslmode"] = "require"

STATIC_ROOT = BASE_DIR / "staticfiles"

STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env_bool("DJANGO_SECURE_SSL_REDIRECT", default=True)
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

SECURE_HSTS_SECONDS = int(os.environ.get("DJANGO_SECURE_HSTS_SECONDS", "31536000"))
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"
X_FRAME_OPTIONS = "DENY"

SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = False

CONN_MAX_AGE = 600

SMTP_EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_BACKEND = os.environ.get("DJANGO_EMAIL_BACKEND", SMTP_EMAIL_BACKEND)
DEFAULT_FROM_EMAIL = required_env("DJANGO_DEFAULT_FROM_EMAIL")
SERVER_EMAIL = os.environ.get("DJANGO_SERVER_EMAIL", DEFAULT_FROM_EMAIL)

if EMAIL_BACKEND == SMTP_EMAIL_BACKEND:
    EMAIL_HOST = required_env("DJANGO_EMAIL_HOST")
    EMAIL_PORT = env_int("DJANGO_EMAIL_PORT", 587)
    EMAIL_HOST_USER = os.environ.get("DJANGO_EMAIL_HOST_USER", "")
    EMAIL_HOST_PASSWORD = os.environ.get("DJANGO_EMAIL_HOST_PASSWORD", "")
    EMAIL_USE_TLS = env_bool("DJANGO_EMAIL_USE_TLS", default=True)
    EMAIL_USE_SSL = env_bool("DJANGO_EMAIL_USE_SSL", default=False)
    EMAIL_TIMEOUT = env_int("DJANGO_EMAIL_TIMEOUT", 10)

    if EMAIL_USE_TLS and EMAIL_USE_SSL:
        raise ImproperlyConfigured(
            "DJANGO_EMAIL_USE_TLS and DJANGO_EMAIL_USE_SSL cannot both be true."
        )

LOGGING["root"]["level"] = os.environ.get("DJANGO_LOG_LEVEL", "INFO")  # noqa: F405
LOGGING["loggers"]["django"]["level"] = os.environ.get(  # noqa: F405
    "DJANGO_LOG_LEVEL",
    "INFO",
)
LOGGING["loggers"]["apps"]["level"] = os.environ.get(  # noqa: F405
    "DJANGO_LOG_LEVEL",
    "INFO",
)
