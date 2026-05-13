"""
Dashboard metric tests for StudyBuddy.
"""

import pytest
from django.urls import reverse

from apps.dashboard.services import build_dashboard_context
from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.sessions.models import StudySession
from apps.users.factories import UserFactory

pytestmark = pytest.mark.django_db


def test_dashboard_metrics_are_scoped_to_current_user() -> None:
    """
    Dashboard metrics include only the supplied user's sessions and notes.
    """

    user = UserFactory()
    other_user = UserFactory()
    completed_session = StudySessionFactory(
        owner=user,
        status=StudySession.Status.COMPLETED,
        duration_minutes=90,
    )
    StudySessionFactory(owner=user, duration_minutes=30)
    StudySessionFactory(owner=other_user, duration_minutes=500)
    StudyNoteFactory(session=completed_session)

    context = build_dashboard_context(user)
    metrics = context["metrics"]

    assert metrics.total_sessions == 2
    assert metrics.completed_sessions == 1
    assert metrics.total_minutes == 120
    assert metrics.note_count == 1


def test_dashboard_renders_metrics_for_authenticated_user(client) -> None:
    """
    The dashboard renders stored study metrics for the logged-in user.
    """

    user = UserFactory()
    session = StudySessionFactory(
        owner=user,
        title="Metrics session",
        status=StudySession.Status.COMPLETED,
        duration_minutes=75,
    )
    StudyNoteFactory(session=session)
    client.force_login(user)

    response = client.get(reverse("dashboard:index"))

    content = response.content.decode()
    assert response.status_code == 200
    assert "Total sessions" in content
    assert "75" in content
    assert "Metrics session" in content


def test_dashboard_empty_state_is_useful_for_new_user(client) -> None:
    """
    New users see an empty dashboard state with a session creation link.
    """

    user = UserFactory()
    client.force_login(user)

    response = client.get(reverse("dashboard:index"))

    content = response.content.decode()
    assert response.status_code == 200
    assert "No study activity yet" in content
    assert reverse("sessions:create") in content
