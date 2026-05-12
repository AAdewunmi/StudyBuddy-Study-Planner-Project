"""Permission tests for user-owned study sessions."""

import pytest
from django.urls import reverse

from apps.sessions.factories import StudySessionFactory
from apps.sessions.models import StudyNote
from apps.users.factories import UserFactory

pytestmark = pytest.mark.django_db


def test_user_cannot_view_another_users_session_detail(client) -> None:
    """A user receives 404 when requesting another user's session."""
    user = UserFactory()
    other_user = UserFactory()
    other_session = StudySessionFactory(owner=other_user)

    client.force_login(user)
    response = client.get(reverse("sessions:detail", kwargs={"pk": other_session.pk}))

    assert response.status_code == 404


def test_user_cannot_update_another_users_session(client) -> None:
    """A user receives 404 when requesting another user's update route."""
    user = UserFactory()
    other_user = UserFactory()
    other_session = StudySessionFactory(owner=other_user)

    client.force_login(user)
    response = client.get(reverse("sessions:update", kwargs={"pk": other_session.pk}))

    assert response.status_code == 404


def test_user_cannot_add_note_to_another_users_session(client) -> None:
    """A user receives 404 before adding a note to another user's session."""
    user = UserFactory()
    other_user = UserFactory()
    other_session = StudySessionFactory(owner=other_user)

    client.force_login(user)
    response = client.post(
        reverse("sessions:add_note", kwargs={"pk": other_session.pk}),
        {"content": "This note should not be attached to another user's session."},
    )

    assert response.status_code == 404
    assert not StudyNote.objects.filter(session=other_session).exists()
