"""Selector tests for study sessions and notes."""

from __future__ import annotations

from datetime import timedelta

import pytest
from django.http import Http404
from django.utils import timezone

from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.sessions.selectors import (
    get_notes_for_session,
    get_recent_sessions_for_user,
    get_session_for_user_or_404,
    get_sessions_for_user,
)
from apps.users.factories import CustomUserFactory

pytestmark = pytest.mark.django_db


def test_get_sessions_for_user_returns_only_owned_sessions() -> None:
    """Session list queries are scoped to the requesting user."""
    user = CustomUserFactory(email="owner@example.com")
    other_user = CustomUserFactory(email="other@example.com")
    owned_session = StudySessionFactory(owner=user, title="Owned session")
    StudySessionFactory(owner=other_user, title="Other session")

    sessions = list(get_sessions_for_user(user))

    assert sessions == [owned_session]


def test_get_session_for_user_or_404_returns_owned_session() -> None:
    """A user can resolve their own study session by primary key."""
    user = CustomUserFactory(email="detail.owner@example.com")
    session = StudySessionFactory(owner=user)

    resolved_session = get_session_for_user_or_404(user, session.pk)

    assert resolved_session == session


def test_get_session_for_user_or_404_rejects_other_users_session() -> None:
    """A user cannot resolve another user's study session."""
    user = CustomUserFactory(email="viewer@example.com")
    other_session = StudySessionFactory()

    with pytest.raises(Http404):
        get_session_for_user_or_404(user, other_session.pk)


def test_get_recent_sessions_for_user_returns_limited_owned_sessions() -> None:
    """Recent session queries keep dashboard activity user-scoped and ordered."""
    user = CustomUserFactory(email="recent.owner@example.com")
    other_user = CustomUserFactory(email="recent.other@example.com")
    today = timezone.localdate()
    newest_session = StudySessionFactory(owner=user, study_date=today)
    older_session = StudySessionFactory(
        owner=user,
        study_date=today - timedelta(days=1),
    )
    StudySessionFactory(owner=user, study_date=today - timedelta(days=2))
    StudySessionFactory(owner=other_user, study_date=today + timedelta(days=1))

    sessions = get_recent_sessions_for_user(user, limit=2)

    assert sessions == [newest_session, older_session]


def test_get_notes_for_session_returns_attached_notes() -> None:
    """Note queries are scoped through the parent study session."""
    session = StudySessionFactory()
    note = StudyNoteFactory(session=session)
    StudyNoteFactory()

    notes = list(get_notes_for_session(session))

    assert notes == [note]
