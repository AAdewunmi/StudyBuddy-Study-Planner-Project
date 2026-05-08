"""Application configuration for study sessions."""

from __future__ import annotations

from django.apps import AppConfig


class StudySessionsConfig(AppConfig):
    """Django application configuration for the study session workflow."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.sessions"
    label = "study_sessions"
