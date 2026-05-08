"""Admin tests for study sessions and notes."""

from __future__ import annotations

import pytest
from django.contrib import admin

from apps.sessions.admin import StudyNoteAdmin
from apps.sessions.models import StudyNote, StudySession
from apps.users.factories import CustomUserFactory

pytestmark = pytest.mark.django_db


def test_study_note_admin_session_owner_returns_owner_email():
    """Study note admin exposes the parent session owner for inspection."""
    user = CustomUserFactory(email="session.owner@example.com")
    session = StudySession.objects.create(
        owner=user,
        title="Review notes",
        subject="History",
        duration_minutes=25,
    )
    note = StudyNote.objects.create(
        session=session,
        content="Timeline notes with enough detail for review.",
    )
    note_admin = StudyNoteAdmin(StudyNote, admin.site)

    assert note_admin.session_owner(note) == "session.owner@example.com"
