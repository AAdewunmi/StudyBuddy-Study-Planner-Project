"""
Application services for study session reporting.
"""

from dataclasses import dataclass
from typing import Any

from django.db.models import Sum

from apps.sessions.models import StudyNote, StudySession
from apps.sessions.selectors import get_recent_sessions_for_user, get_sessions_for_user


@dataclass(frozen=True)
class SessionMetrics:
    """
    User-scoped aggregate metrics for dashboard reporting.
    """

    total_sessions: int
    completed_sessions: int
    total_minutes: int
    note_count: int
    recent_sessions: list[StudySession]


def build_session_metrics_for_user(user: Any) -> SessionMetrics:
    """
    Build dashboard-ready metrics for a single user's study activity.
    """

    sessions = get_sessions_for_user(user)
    total_minutes = sessions.aggregate(total=Sum("duration_minutes"))["total"] or 0

    return SessionMetrics(
        total_sessions=sessions.count(),
        completed_sessions=sessions.filter(status=StudySession.Status.COMPLETED).count(),
        total_minutes=total_minutes,
        note_count=StudyNote.objects.filter(session__owner=user).count(),
        recent_sessions=get_recent_sessions_for_user(user),
    )