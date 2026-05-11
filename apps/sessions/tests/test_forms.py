"""Form tests for study sessions and notes."""

from __future__ import annotations

from django.utils import timezone

from apps.sessions.forms import StudyNoteForm, StudySessionForm
from apps.sessions.models import StudySession


def test_study_session_form_strips_title_and_subject() -> None:
    """Study session form normalizes leading and trailing whitespace."""
    form = StudySessionForm(
        data={
            "title": "  Read Django docs  ",
            "subject": "  Django  ",
            "status": StudySession.Status.PLANNED,
            "study_date": timezone.localdate().isoformat(),
            "duration_minutes": "45",
        }
    )

    assert form.is_valid(), form.errors
    assert form.cleaned_data["title"] == "Read Django docs"
    assert form.cleaned_data["subject"] == "Django"


def test_study_note_form_strips_content() -> None:
    """Study note form normalizes leading and trailing whitespace."""
    form = StudyNoteForm(
        data={
            "content": "  Reviewed model relationships and form validation.  ",
        }
    )

    assert form.is_valid(), form.errors
    assert form.cleaned_data["content"] == (
        "Reviewed model relationships and form validation."
    )
