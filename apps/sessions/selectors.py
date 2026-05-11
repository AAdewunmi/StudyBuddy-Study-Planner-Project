"""Query helpers for StudyBuddy study sessions and notes."""

from __future__ import annotations

from django.contrib.auth import get_user_model
from django.db.models import QuerySet
from django.shortcuts import get_object_or_404

from apps.sessions.models import StudyNote, StudySession

User = get_user_model()


def get_sessions_for_user(user: User) -> QuerySet[StudySession]:
    """Return study sessions owned by the given user."""
    return StudySession.objects.filter(owner=user).prefetch_related("notes")


def get_session_for_user_or_404(user: User, pk: int) -> StudySession:
    """Return one user-owned study session or raise a 404."""
    return get_object_or_404(
        StudySession.objects.filter(owner=user).prefetch_related("notes"),
        pk=pk,
    )


def get_notes_for_session(session: StudySession) -> QuerySet[StudyNote]:
    """Return notes attached to a study session."""
    return session.notes.all()
