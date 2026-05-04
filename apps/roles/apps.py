"""Role application configuration."""

from __future__ import annotations

from django.apps import AppConfig


class RolesConfig(AppConfig):
    """Configure the roles application."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.roles"
