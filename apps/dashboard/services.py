"""
Dashboard services for StudyBuddy.

The dashboard service composes user-scoped data from domain services and
returns a template-ready context dictionary.
"""

from typing import Any

from apps.sessions.services import build_session_metrics_for_user


def build_dashboard_context(user: Any) -> dict[str, Any]:
    """
    Build context data for the authenticated user's dashboard.
    """

    metrics = build_session_metrics_for_user(user)

    return {
        "metrics": metrics,
        "recent_activity": metrics.recent_sessions,
    }