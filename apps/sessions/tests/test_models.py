"""Model tests for study sessions and notes."""

from __future__ import annotations

from datetime import timedelta

import pytest
from django.core.exceptions import ValidationError
from django.utils import timezone

from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.sessions.models import StudySession
from apps.users.factories import CustomUserFactory

pytestmark = pytest.mark.django_db


def test_study_session_persists_with_owner() -> None:
    """Study sessions persist with the user that owns them."""
    user = CustomUserFactory(email="owner@example.com")
    session = StudySessionFactory(
        owner=user,
        title="Read Django docs",
        subject="Django",
    )

    assert session.owner == user
    assert session.title == "Read Django docs"
    assert str(session) == "Read Django docs (Django)"


def test_study_session_reports_note_count() -> None:
    """Study sessions expose note count metadata for dashboard and detail views."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session)
    StudyNoteFactory(session=session)

    assert session.note_count == 2


def test_unsaved_study_session_reports_zero_notes() -> None:
    """Unsaved study sessions report zero notes without querying the database."""
    session = StudySessionFactory.build()

    assert session.note_count == 0


def test_study_session_rejects_zero_duration() -> None:
    """A study session cannot have a zero-minute duration."""
    session = StudySessionFactory.build(
        owner=CustomUserFactory(),
        duration_minutes=0,
    )

    with pytest.raises(ValidationError):
        session.full_clean()


def test_study_session_rejects_duration_above_one_day() -> None:
    """A study session cannot exceed 24 hours."""
    session = StudySessionFactory.build(
        owner=CustomUserFactory(),
        duration_minutes=1441,
    )

    with pytest.raises(ValidationError):
        session.full_clean()


def test_completed_study_session_cannot_be_in_future() -> None:
    """Completed sessions cannot be dated after today."""
    session = StudySessionFactory.build(
        owner=CustomUserFactory(),
        status=StudySession.Status.COMPLETED,
        study_date=timezone.localdate() + timedelta(days=1),
    )

    with pytest.raises(ValidationError):
        session.full_clean()


def test_planned_future_session_is_valid() -> None:
    """Planned sessions may be scheduled for a future date."""
    session = StudySessionFactory.build(
        owner=CustomUserFactory(),
        status=StudySession.Status.PLANNED,
        study_date=timezone.localdate() + timedelta(days=1),
    )

    session.full_clean()


def test_study_note_validation_string_and_word_count() -> None:
    """Study notes validate useful content and expose simple text metrics."""
    note = StudyNoteFactory.build(
        content="Thesis evidence and paragraph plan.",
        session__title="Essay outline",
    )

    assert str(note) == "Note for Essay outline"
    assert note.word_count == 5

    note.content = "short"

    with pytest.raises(ValidationError) as error:
        note.clean()

    assert "content" in error.value.message_dict
