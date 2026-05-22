"""
Dashboard services for StudyBuddy.

The dashboard service composes user-scoped data from domain services and
returns a template-ready context dictionary.
"""

from dataclasses import dataclass
from os import environ
from typing import Any

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.models import Avg, Sum
from django.utils import timezone

from apps.insights.metrics import KeywordMetric
from apps.insights.models import StudyInsight
from apps.roles.models import Role
from apps.roles.permissions import user_has_role
from apps.sessions.models import StudyNote, StudySession
from apps.sessions.services import build_session_metrics_for_user


@dataclass(frozen=True)
class CountMetric:
    """Template-ready label/count pair for admin dashboard cards."""

    label: str
    count: int


@dataclass(frozen=True)
class PlatformMetrics:
    """Operational dashboard metrics for admin users."""

    total_users: int
    total_students: int
    total_tutors: int
    total_admins: int
    users_without_roles: int
    recent_users: list[Any]
    total_sessions: int
    completed_sessions: int
    in_progress_sessions: int
    planned_sessions: int
    total_study_minutes: int
    total_notes: int
    recent_sessions: list[StudySession]
    total_insights: int
    average_confidence: int
    sessions_with_insights: int
    sessions_without_insights: int
    recent_insights: list[StudyInsight]
    top_keywords: list[KeywordMetric]
    role_distribution: list[CountMetric]
    staff_users: int
    superusers: int
    inactive_users: int
    object_counts: list[CountMetric]
    last_activity_at: object | None
    release_sha: str
    environment_name: str
    health_status: str


def build_dashboard_context(user: Any) -> dict[str, Any]:
    """
    Build context data for the authenticated user's dashboard.
    """

    metrics = build_session_metrics_for_user(user)
    is_admin_dashboard = user_has_role(user, "admin")

    return {
        "dashboard_variant": "admin" if is_admin_dashboard else "user",
        "platform_metrics": (build_platform_metrics() if is_admin_dashboard else None),
        "metrics": metrics,
        "recent_activity": metrics.recent_sessions,
        "roles": user.studybuddy_roles.order_by("display_name"),
    }


def build_platform_metrics() -> PlatformMetrics:
    """Build database-backed operational metrics for admin users."""
    User = get_user_model()
    users = User.objects.all()
    sessions = StudySession.objects.select_related("owner").prefetch_related("notes")
    insights = StudyInsight.objects.select_related("session", "session__owner")
    total_sessions = sessions.count()
    sessions_with_insights = insights.values("session_id").distinct().count()
    average_confidence = insights.aggregate(average=Avg("confidence"))["average"] or 0

    return PlatformMetrics(
        total_users=users.count(),
        total_students=users.filter(studybuddy_roles__slug="student")
        .distinct()
        .count(),
        total_tutors=users.filter(studybuddy_roles__slug="tutor").distinct().count(),
        total_admins=users.filter(studybuddy_roles__slug="admin").distinct().count(),
        users_without_roles=users.filter(studybuddy_roles__isnull=True).count(),
        recent_users=list(users.order_by("-date_joined")[:5]),
        total_sessions=total_sessions,
        completed_sessions=sessions.filter(
            status=StudySession.Status.COMPLETED
        ).count(),
        in_progress_sessions=sessions.filter(
            status=StudySession.Status.IN_PROGRESS
        ).count(),
        planned_sessions=sessions.filter(status=StudySession.Status.PLANNED).count(),
        total_study_minutes=sessions.aggregate(total=Sum("duration_minutes"))["total"]
        or 0,
        total_notes=StudyNote.objects.count(),
        recent_sessions=list(sessions.order_by("-study_date", "-created_at")[:5]),
        total_insights=insights.count(),
        average_confidence=round(average_confidence),
        sessions_with_insights=sessions_with_insights,
        sessions_without_insights=max(total_sessions - sessions_with_insights, 0),
        recent_insights=list(insights.order_by("-created_at", "-id")[:5]),
        top_keywords=_build_platform_top_keywords(insights),
        role_distribution=_build_role_distribution(),
        staff_users=users.filter(is_staff=True).count(),
        superusers=users.filter(is_superuser=True).count(),
        inactive_users=users.filter(is_active=False).count(),
        object_counts=[
            CountMetric("Users", users.count()),
            CountMetric("Sessions", total_sessions),
            CountMetric("Notes", StudyNote.objects.count()),
            CountMetric("Insights", insights.count()),
        ],
        last_activity_at=_latest_activity_timestamp(users, sessions, insights),
        release_sha=environ.get("RELEASE_SHA")
        or environ.get("RENDER_GIT_COMMIT")
        or "local",
        environment_name=getattr(settings, "ENVIRONMENT", "local"),
        health_status="OK",
    )


def _build_role_distribution() -> list[CountMetric]:
    """Return user counts by product role."""
    return [
        CountMetric(role.display_name, role.users.count())
        for role in Role.objects.order_by("display_name")
    ]


def _build_platform_top_keywords(insights: Any, limit: int = 8) -> list[KeywordMetric]:
    """Return keyword frequency across all generated insights."""
    keyword_counts: dict[str, int] = {}

    for keywords in insights.values_list("keywords", flat=True):
        for keyword in keywords or []:
            normalised_keyword = keyword.strip().lower()
            if normalised_keyword:
                keyword_counts[normalised_keyword] = (
                    keyword_counts.get(normalised_keyword, 0) + 1
                )

    return [
        KeywordMetric(label=keyword, count=count)
        for keyword, count in sorted(
            keyword_counts.items(),
            key=lambda item: (-item[1], item[0]),
        )[:limit]
    ]


def _latest_activity_timestamp(
    users: Any,
    sessions: Any,
    insights: Any,
) -> object | None:
    """Return the latest timestamp available across key platform records."""
    timestamps = [
        users.order_by("-date_joined").values_list("date_joined", flat=True).first(),
        sessions.order_by("-created_at").values_list("created_at", flat=True).first(),
        insights.order_by("-created_at").values_list("created_at", flat=True).first(),
    ]
    timestamps = [timestamp for timestamp in timestamps if timestamp is not None]
    return max(timestamps) if timestamps else timezone.now()
