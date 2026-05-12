"""Update workflow tests for study sessions."""

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.sessions.factories import StudySessionFactory
from apps.sessions.models import StudySession
from apps.users.factories import UserFactory

pytestmark = pytest.mark.django_db


def _session_form_data(**overrides):
    """Return valid update form data with optional field overrides."""
    data = {
        "title": "Updated session title",
        "subject": "PostgreSQL",
        "status": StudySession.Status.IN_PROGRESS,
        "study_date": timezone.localdate().isoformat(),
        "duration_minutes": "90",
    }
    data.update(overrides)
    return data


def test_user_can_open_update_form_for_owned_session(client) -> None:
    """The update form is populated only after resolving an owned session."""
    user = UserFactory()
    session = StudySessionFactory(owner=user, title="Original title")
    client.force_login(user)

    response = client.get(reverse("sessions:update", kwargs={"pk": session.pk}))

    assert response.status_code == 200
    assert response.context["session"] == session
    assert response.context["page_title"] == "Edit study session"
    assert response.context["submit_label"] == "Save changes"
    assert b"Original title" in response.content


def test_user_can_update_owned_session(client) -> None:
    """A valid update saves through the session form and redirects to detail."""
    user = UserFactory()
    session = StudySessionFactory(owner=user, title="Original title")
    client.force_login(user)

    response = client.post(
        reverse("sessions:update", kwargs={"pk": session.pk}),
        _session_form_data(),
    )

    session.refresh_from_db()
    assert response.status_code == 302
    assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
    assert session.title == "Updated session title"
    assert session.subject == "PostgreSQL"
    assert session.status == StudySession.Status.IN_PROGRESS
    assert session.duration_minutes == 90


def test_invalid_update_rerenders_form_without_saving(client) -> None:
    """Invalid form data is rejected without changing the owned session."""
    user = UserFactory()
    session = StudySessionFactory(
        owner=user,
        title="Original title",
        duration_minutes=45,
    )
    client.force_login(user)

    response = client.post(
        reverse("sessions:update", kwargs={"pk": session.pk}),
        _session_form_data(duration_minutes="0"),
    )

    session.refresh_from_db()
    assert response.status_code == 200
    assert response.context["session"] == session
    assert b"Ensure this value is greater than or equal to 1." in response.content
    assert session.title == "Original title"
    assert session.duration_minutes == 45


def test_user_cannot_update_another_users_session(client) -> None:
    """The update view 404s before binding the form for another user's session."""
    owner = UserFactory()
    other_user = UserFactory()
    session = StudySessionFactory(
        owner=owner,
        title="Owner session",
        subject="Django",
        duration_minutes=45,
    )
    client.force_login(other_user)

    response = client.post(
        reverse("sessions:update", kwargs={"pk": session.pk}),
        _session_form_data(title="Cross-user edit", subject="Security"),
    )

    session.refresh_from_db()
    assert response.status_code == 404
    assert session.owner == owner
    assert session.title == "Owner session"
    assert session.subject == "Django"
    assert session.duration_minutes == 45
