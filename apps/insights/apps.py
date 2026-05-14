"""Application configuration for study insights."""

from __future__ import annotations

from django.apps import AppConfig


class InsightsConfig(AppConfig):
    """Django application configuration for deterministic study insights."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.insights"
    verbose_name = "Study insights"
