"""Application configuration for the users app."""

from __future__ import annotations

from django.apps import AppConfig


class UsersConfig(AppConfig):
    """Configure the users application."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.users"
    label = "users"
