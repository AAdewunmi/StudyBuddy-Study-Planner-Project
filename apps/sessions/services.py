"""
Application services for study session reporting.
"""

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Any

from django.db.models import Sum
from django.utils import timezone

from apps.sessions.models import StudySession
from apps.sessions.selectors import (
    get_notes_for_user,
    get_recent_sessions_for_user,
    get_sessions_for_user,
)


@dataclass(frozen=True)
class CountMetric:
    """
    Template-ready label/count pair for dashboard summary cards.
    """

    label: str
    count: int


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
    average_session_minutes: int
    study_day_count: int
    current_streak_days: int
    monthly_sessions: int
    monthly_completed_sessions: int
    monthly_minutes: int
    sessions_with_notes: int
    sessions_without_notes: int
    status_counts: list[CountMetric]
    subject_counts: list[CountMetric]


def build_session_metrics_for_user(user: Any) -> SessionMetrics:
    """
    Build dashboard-ready metrics for a single user's study activity.
    """

    sessions = get_sessions_for_user(user)
    total_sessions = sessions.count()
    total_minutes = sessions.aggregate(total=Sum("duration_minutes"))["total"] or 0
    completed_sessions = sessions.filter(status=StudySession.Status.COMPLETED).count()
    today = timezone.localdate()
    month_start = today.replace(day=1)
    monthly_sessions = sessions.filter(study_date__gte=month_start).count()
    monthly_completed_sessions = sessions.filter(
        status=StudySession.Status.COMPLETED,
        study_date__gte=month_start,
    ).count()
    monthly_minutes = (
        sessions.filter(study_date__gte=month_start).aggregate(
            total=Sum("duration_minutes")
        )["total"]
        or 0
    )
    study_dates = set(sessions.values_list("study_date", flat=True))
    sessions_with_notes = sum(1 for session in sessions if session.note_count > 0)

    return SessionMetrics(
        total_sessions=total_sessions,
        completed_sessions=completed_sessions,
        total_minutes=total_minutes,
        note_count=get_notes_for_user(user).count(),
        recent_sessions=get_recent_sessions_for_user(user),
        average_session_minutes=(
            round(total_minutes / total_sessions) if total_sessions else 0
        ),
        study_day_count=len(study_dates),
        current_streak_days=_calculate_streak_days(study_dates),
        monthly_sessions=monthly_sessions,
        monthly_completed_sessions=monthly_completed_sessions,
        monthly_minutes=monthly_minutes,
        sessions_with_notes=sessions_with_notes,
        sessions_without_notes=total_sessions - sessions_with_notes,
        status_counts=_build_status_counts(sessions),
        subject_counts=_build_subject_counts(sessions),
    )


def _calculate_streak_days(study_dates: set[date]) -> int:
    """Return consecutive study days ending at the latest study date."""
    if not study_dates:
        return 0

    current_date = max(study_dates)
    streak = 0

    while current_date in study_dates:
        streak += 1
        current_date -= timedelta(days=1)

    return streak


def _build_status_counts(sessions: Any) -> list[CountMetric]:
    """Return session counts grouped by status display label."""
    return [
        CountMetric(
            label=label,
            count=sessions.filter(status=status).count(),
        )
        for status, label in StudySession.Status.choices
    ]


def _build_subject_counts(sessions: Any, limit: int = 5) -> list[CountMetric]:
    """Return the most common session subjects for template display."""
    subjects: dict[str, int] = {}
    for subject in sessions.values_list("subject", flat=True):
        subjects[subject] = subjects.get(subject, 0) + 1

    return [
        CountMetric(label=subject, count=count)
        for subject, count in sorted(
            subjects.items(),
            key=lambda item: (-item[1], item[0].lower()),
        )[:limit]
    ]
