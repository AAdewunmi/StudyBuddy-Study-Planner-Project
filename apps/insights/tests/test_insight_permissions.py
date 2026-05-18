"""Permission tests for insight generation."""

from __future__ import annotations

import pytest
from django.core.exceptions import PermissionDenied
from django.urls import reverse

from apps.insights.models import StudyInsight
from apps.insights.services import generate_insight_for_session
from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.users.factories import UserFactory

pytestmark = pytest.mark.django_db


def test_service_rejects_generation_for_another_users_session() -> None:
    """The service should enforce session ownership."""
    session = StudySessionFactory()
    other_user = UserFactory()

    with pytest.raises(PermissionDenied):
        generate_insight_for_session(session=session, requested_by=other_user)


def test_view_allows_owner_to_generate_insight(client) -> None:
    """The owner should be able to generate an insight from the session page."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session, content="Django testing workflow.")
    client.force_login(session.owner)

    response = client.post(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
    )

    assert response.status_code == 302
    assert StudyInsight.objects.filter(owner=session.owner, session=session).exists()


def test_view_returns_404_for_another_users_session(client) -> None:
    """The generation route should not reveal another user's session."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session, content="Private study notes.")
    other_user = UserFactory()
    client.force_login(other_user)

    response = client.post(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
    )

    assert response.status_code == 404
    assert StudyInsight.objects.count() == 0