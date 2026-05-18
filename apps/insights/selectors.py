"""Read selectors for study insights."""

from __future__ import annotations

from django.db.models import QuerySet

from apps.insights.models import StudyInsight


def get_user_insights(user: object) -> QuerySet[StudyInsight]:
    """Return insights attached to sessions owned by a user.

    Args:
        user: Authenticated user.

    Returns:
        QuerySet of user-scoped insights.
    """
    return (
        StudyInsight.objects.filter(session__owner=user)
        .select_related("session", "session__owner")
        .order_by("-created_at", "-id")
    )


def get_latest_session_insight(
    *,
    session: object,
    user: object,
) -> StudyInsight | None:
    """Return the latest insight for a user-owned session.

    Args:
        session: Study session instance.
        user: Authenticated user.

    Returns:
        Latest matching insight or ``None``.
    """
    return (
        StudyInsight.objects.filter(session=session, session__owner=user)
        .select_related("session", "session__owner")
        .order_by("-created_at", "-id")
        .first()
    )
