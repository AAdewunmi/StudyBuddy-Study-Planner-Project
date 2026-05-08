"""Model tests for study sessions and notes."""

from __future__ import annotations

import pytest
from django.core.exceptions import ValidationError
from django.utils import timezone

from apps.sessions.models import StudyNote, StudySession
from apps.users.factories import CustomUserFactory

pytestmark = pytest.mark.django_db


def test_study_session_string_and_note_count():
    """Study sessions expose readable labels and count attached notes."""
    user = CustomUserFactory()
    unsaved_session = StudySession(
        owner=user,
        title="Read chapter 4",
        subject="Biology",
        duration_minutes=45,
    )

    assert str(unsaved_session) == "Read chapter 4 (Biology)"
    assert unsaved_session.note_count == 0

    unsaved_session.save()
    StudyNote.objects.create(
        session=unsaved_session,
        content="Mitosis notes from the assigned textbook chapter.",
    )

    assert unsaved_session.note_count == 1


def test_completed_session_cannot_be_dated_in_future():
    """Completed sessions cannot point at a future study date."""
    session = StudySession(
        owner=CustomUserFactory(),
        title="Future review",
        subject="Chemistry",
        status=StudySession.Status.COMPLETED,
        study_date=timezone.localdate() + timezone.timedelta(days=1),
        duration_minutes=30,
    )

    with pytest.raises(ValidationError) as error:
        session.clean()

    assert "study_date" in error.value.message_dict


def test_planned_future_session_is_valid():
    """Planned sessions may be scheduled for a future date."""
    session = StudySession(
        owner=CustomUserFactory(),
        title="Schedule revision",
        subject="Maths",
        status=StudySession.Status.PLANNED,
        study_date=timezone.localdate() + timezone.timedelta(days=1),
        duration_minutes=60,
    )

    session.clean()


def test_study_note_validation_string_and_word_count():
    """Study notes validate useful content and expose simple text metrics."""
    session = StudySession.objects.create(
        owner=CustomUserFactory(),
        title="Essay outline",
        subject="English",
        duration_minutes=50,
    )
    note = StudyNote(
        session=session,
        content="Thesis evidence and paragraph plan.",
    )

    assert str(note) == "Note for Essay outline"
    assert note.word_count == 5

    note.content = "short"

    with pytest.raises(ValidationError) as error:
        note.clean()

    assert "content" in error.value.message_dict
