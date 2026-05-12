"""
Permission tests for user-owned study sessions.
"""

import pytest
from django.urls import reverse

from apps.sessions.factories import StudySessionFactory
from apps.users.factories import UserFactory


pytestmark = pytest.mark.django_db


def test_user_cannot_view_another_users_session_detail(client) -> None:
    """
    A user receives 404 when requesting another user's session.
    """

    user = UserFactory()
    other_user = UserFactory()
    other_session = StudySessionFactory(owner=other_user)

    client.force_login(user)
    response = client.get(reverse("sessions:detail", kwargs={"pk": other_session.pk}))

    assert response.status_code == 404


def test_user_cannot_update_another_users_session(client) -> None:
    """
    A user receives 404 when requesting another user's update route.
    """

    user = UserFactory()
    other_user = UserFactory()
    other_session = StudySessionFactory(owner=other_user)

    client.force_login(user)
    response = client.get(reverse("sessions:update", kwargs={"pk": other_session.pk}))

    assert response.status_code == 404