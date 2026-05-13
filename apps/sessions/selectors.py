"""
Query selectors for study sessions and notes.

Selectors keep user-scoped query rules in one place so views, services, and
future API endpoints do not each invent their own ownership logic.
"""

from __future__ import annotations

from typing import Any

from django.db.models import QuerySet
from django.shortcuts import get_object_or_404

from apps.sessions.models import StudyNote, StudySession


def get_sessions_for_user(user: Any) -> QuerySet[StudySession]:
    """
    Return all study sessions owned by the supplied user.
    """

    return (
        StudySession.objects.filter(owner=user)
        .prefetch_related("notes")
        .order_by("-study_date", "-created_at")
    )


def get_session_for_user_or_404(
    user: Any,
    pk: int,
) -> StudySession:
    """
    Return one user-owned study session or raise Http404.
    """

    return get_object_or_404(get_sessions_for_user(user), pk=pk)


def get_recent_sessions_for_user(user: Any, limit: int = 5) -> list[StudySession]:
    """
    Return the most recent sessions for dashboard activity.
    """

    return list(get_sessions_for_user(user)[:limit])


def get_notes_for_session(session: StudySession) -> QuerySet[StudyNote]:
    """
    Return notes belonging to the supplied session.
    """

    return session.notes.all().order_by("-created_at")


def get_notes_for_user(user: Any) -> QuerySet[StudyNote]:
    """
    Return notes attached to sessions owned by the supplied user.
    """

    return (
        StudyNote.objects.select_related("session")
        .filter(session__owner=user)
        .order_by("-created_at")
    )


def get_note_for_user_or_404(
    user: Any,
    session_pk: int,
    note_pk: int,
) -> StudyNote:
    """
    Return one note attached to a user-owned study session or raise Http404.
    """

    return get_object_or_404(
        StudyNote.objects.select_related("session").filter(
            session__owner=user,
            session_id=session_pk,
        ),
        pk=note_pk,
    )
