"""
View tests for listing and creating study sessions.
"""

import pytest
from django.urls import reverse

from apps.sessions.factories import StudySessionFactory
from apps.sessions.models import StudySession
from apps.users.factories import UserFactory

pytestmark = pytest.mark.django_db


def test_anonymous_user_is_redirected_from_session_list(client) -> None:
    """
    Anonymous users cannot access the session list.
    """

    response = client.get(reverse("sessions:list"))

    assert response.status_code == 302
    assert "/users/login/" in response["Location"]


def test_authenticated_user_sees_empty_session_list(client) -> None:
    """
    A new authenticated user receives a useful empty state.
    """

    user = UserFactory()
    client.force_login(user)

    response = client.get(reverse("sessions:list"))

    assert response.status_code == 200
    assert "No study sessions yet" in response.content.decode()


def test_session_list_only_shows_current_user_sessions(client) -> None:
    """
    The session list is scoped to the authenticated user.
    """

    user = UserFactory()
    other_user = UserFactory()
    own_session = StudySessionFactory(owner=user, title="Own Django session")
    StudySessionFactory(owner=other_user, title="Other user's session")

    client.force_login(user)
    response = client.get(reverse("sessions:list"))

    content = response.content.decode()
    assert response.status_code == 200
    assert own_session.title in content
    assert "Other user's session" not in content


def test_authenticated_user_can_open_create_session_page(client) -> None:
    """
    Authenticated users can access the create session page.
    """

    user = UserFactory()
    client.force_login(user)

    response = client.get(reverse("sessions:create"))

    assert response.status_code == 200
    assert "Create study session" in response.content.decode()


def test_authenticated_user_can_create_session(client) -> None:
    """
    Posting a valid form creates a session owned by the current user.
    """

    user = UserFactory()
    client.force_login(user)

    response = client.post(
        reverse("sessions:create"),
        {
            "title": "Revise class-based views",
            "subject": "Django",
            "status": StudySession.Status.PLANNED,
            "study_date": "2026-04-27",
            "duration_minutes": "60",
        },
    )

    session = StudySession.objects.get(owner=user)
    assert response.status_code == 302
    assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
    assert session.title == "Revise class-based views"


def test_invalid_session_duration_is_rejected(client) -> None:
    """
    Invalid form data does not create a study session.
    """

    user = UserFactory()
    client.force_login(user)

    response = client.post(
        reverse("sessions:create"),
        {
            "title": "Bad duration",
            "subject": "Django",
            "status": StudySession.Status.PLANNED,
            "study_date": "2026-04-27",
            "duration_minutes": "0",
        },
    )

    assert response.status_code == 200
    assert StudySession.objects.filter(owner=user).count() == 0
    assert (
        "Ensure this value is greater than or equal to 1" in response.content.decode()
    )


def test_anonymous_user_is_redirected_from_create_session_page(client) -> None:
    """
    Anonymous users cannot open the create session form.
    """

    response = client.get(reverse("sessions:create"))

    assert response.status_code == 302
    assert "/users/login/" in response["Location"]
