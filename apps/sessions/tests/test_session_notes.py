"""Tests for editing and deleting study notes."""

from __future__ import annotations

import pytest
from django.urls import reverse

from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.sessions.models import StudyNote
from apps.users.factories import UserFactory

pytestmark = pytest.mark.django_db


def test_session_detail_renders_note_edit_and_delete_controls(client) -> None:
    """The detail page exposes controls for owned note maintenance."""
    user = UserFactory()
    session = StudySessionFactory(owner=user)
    note = StudyNoteFactory(session=session)
    client.force_login(user)

    response = client.get(reverse("sessions:detail", kwargs={"pk": session.pk}))

    content = response.content.decode()
    assert response.status_code == 200
    assert (
        reverse(
            "sessions:update_note",
            kwargs={"pk": session.pk, "note_pk": note.pk},
        )
        in content
    )
    assert (
        reverse(
            "sessions:delete_note",
            kwargs={"pk": session.pk, "note_pk": note.pk},
        )
        in content
    )


def test_user_can_update_owned_note(client) -> None:
    """A valid note update changes an owned note and redirects to detail."""
    user = UserFactory()
    session = StudySessionFactory(owner=user)
    note = StudyNoteFactory(session=session, content="Original note content.")
    client.force_login(user)

    response = client.post(
        reverse(
            "sessions:update_note",
            kwargs={"pk": session.pk, "note_pk": note.pk},
        ),
        {"content": "Updated note content with enough detail."},
    )

    note.refresh_from_db()
    assert response.status_code == 302
    assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
    assert note.content == "Updated note content with enough detail."


def test_invalid_note_update_rerenders_detail_without_saving(client) -> None:
    """Invalid note updates show form errors and leave the note unchanged."""
    user = UserFactory()
    session = StudySessionFactory(owner=user)
    note = StudyNoteFactory(session=session, content="Original note content.")
    client.force_login(user)

    response = client.post(
        reverse(
            "sessions:update_note",
            kwargs={"pk": session.pk, "note_pk": note.pk},
        ),
        {"content": "short"},
    )

    note.refresh_from_db()
    assert response.status_code == 400
    assert response.context["session"] == session
    assert response.context["editing_note"] == note
    assert b"Study notes must contain at least 10 characters." in response.content
    assert note.content == "Original note content."


def test_user_can_delete_owned_note(client) -> None:
    """Deleting an owned note removes it and redirects to detail."""
    user = UserFactory()
    session = StudySessionFactory(owner=user)
    note = StudyNoteFactory(session=session)
    client.force_login(user)

    response = client.post(
        reverse(
            "sessions:delete_note",
            kwargs={"pk": session.pk, "note_pk": note.pk},
        ),
    )

    assert response.status_code == 302
    assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
    assert not StudyNote.objects.filter(pk=note.pk).exists()


def test_user_cannot_update_another_users_note(client) -> None:
    """Note updates are scoped through the current user's session ownership."""
    owner = UserFactory()
    other_user = UserFactory()
    session = StudySessionFactory(owner=owner)
    note = StudyNoteFactory(session=session, content="Owner note content.")
    client.force_login(other_user)

    response = client.post(
        reverse(
            "sessions:update_note",
            kwargs={"pk": session.pk, "note_pk": note.pk},
        ),
        {"content": "Attempted cross-user note edit."},
    )

    note.refresh_from_db()
    assert response.status_code == 404
    assert note.content == "Owner note content."


def test_user_cannot_delete_another_users_note(client) -> None:
    """Note deletes are scoped through the current user's session ownership."""
    owner = UserFactory()
    other_user = UserFactory()
    session = StudySessionFactory(owner=owner)
    note = StudyNoteFactory(session=session)
    client.force_login(other_user)

    response = client.post(
        reverse(
            "sessions:delete_note",
            kwargs={"pk": session.pk, "note_pk": note.pk},
        ),
    )

    assert response.status_code == 404
    assert StudyNote.objects.filter(pk=note.pk).exists()


def test_user_cannot_update_note_through_another_session_route(client) -> None:
    """A note cannot be updated through a different session URL."""
    user = UserFactory()
    note_session = StudySessionFactory(owner=user)
    other_session = StudySessionFactory(owner=user)
    note = StudyNoteFactory(session=note_session, content="Original note content.")
    client.force_login(user)

    response = client.post(
        reverse(
            "sessions:update_note",
            kwargs={"pk": other_session.pk, "note_pk": note.pk},
        ),
        {"content": "Attempted note edit through the wrong session."},
    )

    note.refresh_from_db()
    assert response.status_code == 404
    assert note.content == "Original note content."
