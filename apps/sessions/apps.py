"""
Application configuration for study sessions.
"""

from django.apps import AppConfig


class SessionsConfig(AppConfig):
    """
    Django application configuration for the study session workflow.
    """

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.sessions"
    label = "sessions"