"""Service tests for study session reporting."""

from __future__ import annotations

from datetime import timedelta

import pytest
from django.utils import timezone

from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.sessions.models import StudySession
from apps.sessions.services import build_session_metrics_for_user
from apps.users.factories import CustomUserFactory

pytestmark = pytest.mark.django_db


def test_build_session_metrics_for_user_returns_owned_activity_summary() -> None:
    """Session metrics aggregate only the supplied user's study activity."""
    user = CustomUserFactory(email="metrics.owner@example.com")
    other_user = CustomUserFactory(email="metrics.other@example.com")
    today = timezone.localdate()
    completed_session = StudySessionFactory(
        owner=user,
        status=StudySession.Status.COMPLETED,
        study_date=today,
        duration_minutes=30,
    )
    planned_session = StudySessionFactory(
        owner=user,
        status=StudySession.Status.PLANNED,
        study_date=today - timedelta(days=1),
        duration_minutes=45,
    )
    other_session = StudySessionFactory(
        owner=other_user,
        status=StudySession.Status.COMPLETED,
        study_date=today + timedelta(days=1),
        duration_minutes=120,
    )
    StudyNoteFactory(session=completed_session)
    StudyNoteFactory(session=planned_session)
    StudyNoteFactory(session=other_session)

    metrics = build_session_metrics_for_user(user)

    assert metrics.total_sessions == 2
    assert metrics.completed_sessions == 1
    assert metrics.total_minutes == 75
    assert metrics.note_count == 2
    assert metrics.recent_sessions == [completed_session, planned_session]
