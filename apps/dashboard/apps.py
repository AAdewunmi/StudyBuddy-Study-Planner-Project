"""Application configuration for the dashboard app."""

from __future__ import annotations

from django.apps import AppConfig


class DashboardConfig(AppConfig):
    """Configure the StudyBuddy dashboard app."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.dashboard"
    label = "dashboard"
