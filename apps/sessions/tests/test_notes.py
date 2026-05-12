"""
Tests for study notes attached to sessions.
"""

import pytest
from django.urls import reverse

from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.sessions.models import StudyNote
from apps.users.factories import UserFactory


pytestmark = pytest.mark.django_db


def test_user_can_add_note_to_owned_session(client) -> None:
    """
    A user can add a note to a session they own.
    """

    user = UserFactory()
    session = StudySessionFactory(owner=user)
    client.force_login(user)

    response = client.post(
        reverse("sessions:add_note", kwargs={"pk": session.pk}),
        {
            "content": "Reviewed the service layer and selector pattern today.",
        },
    )

    assert response.status_code == 302
    assert StudyNote.objects.filter(session=session).count() == 1


def test_notes_appear_on_session_detail_page(client) -> None:
    """
    Notes attached to a session are rendered on the detail page.
    """

    user = UserFactory()
    session = StudySessionFactory(owner=user)
    StudyNoteFactory(
        session=session,
        content="Captured notes about Django forms and model validation.",
    )
    client.force_login(user)

    response = client.get(reverse("sessions:detail", kwargs={"pk": session.pk}))

    assert response.status_code == 200
    assert "Captured notes about Django forms" in response.content.decode()


def test_user_cannot_add_note_to_another_users_session(client) -> None:
    """
    A user cannot attach notes to another user's session.
    """

    user = UserFactory()
    other_user = UserFactory()
    other_session = StudySessionFactory(owner=other_user)
    client.force_login(user)

    response = client.post(
        reverse("sessions:add_note", kwargs={"pk": other_session.pk}),
        {
            "content": "This note should not be attached to a foreign session.",
        },
    )

    assert response.status_code == 404
    assert StudyNote.objects.filter(session=other_session).count() == 0


def test_short_note_content_is_rejected(client) -> None:
    """
    Notes with too little content are rejected.
    """

    user = UserFactory()
    session = StudySessionFactory(owner=user)
    client.force_login(user)

    response = client.post(
        reverse("sessions:add_note", kwargs={"pk": session.pk}),
        {
            "content": "Too short",
        },
    )

    assert response.status_code == 400
    assert StudyNote.objects.filter(session=session).count() == 0
    assert "Study notes must contain at least 10 characters" in response.content.decode()