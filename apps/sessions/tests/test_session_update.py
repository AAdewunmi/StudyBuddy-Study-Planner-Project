"""
Update workflow tests for study sessions.
"""

import pytest
from django.urls import reverse

from apps.sessions.factories import StudySessionFactory
from apps.sessions.models import StudySession
from apps.users.factories import UserFactory


pytestmark = pytest.mark.django_db


def test_user_can_update_owned_session(client) -> None:
    """
    A user can update a session they own.
    """

    user = UserFactory()
    session = StudySessionFactory(owner=user, title="Original title")
    client.force_login(user)

    response = client.post(
        reverse("sessions:update", kwargs={"pk": session.pk}),
        {
            "title": "Updated session title",
            "subject": "PostgreSQL",
            "status": StudySession.Status.IN_PROGRESS,
            "study_date": "2026-04-27",
            "duration_minutes": "90",
        },
    )

    session.refresh_from_db()
    assert response.status_code == 302
    assert session.title == "Updated session title"
    assert session.subject == "PostgreSQL"
    assert session.duration_minutes == 90