"""Permission tests for insight generation."""

from __future__ import annotations

import pytest
from django.core.exceptions import PermissionDenied
from django.test import RequestFactory
from django.urls import reverse

from apps.insights.factories import StudyInsightFactory
from apps.insights.models import StudyInsight
from apps.insights.services import generate_insight_for_session
from apps.insights.views import InsightListView
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
    assert StudyInsight.objects.filter(
        session=session,
        session__owner=session.owner,
    ).exists()


def test_view_reuses_existing_insight_when_notes_are_unchanged(client) -> None:
    """Repeated generation should reuse the unchanged session insight."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session, content="Django testing workflow.")
    generate_insight_for_session(session=session, requested_by=session.owner)
    client.force_login(session.owner)

    response = client.post(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
    )

    assert response.status_code == 302
    assert StudyInsight.objects.filter(session=session).count() == 1


def test_list_view_queryset_is_scoped_to_authenticated_user() -> None:
    """Insight list reads should return only the current user's insights."""
    user = UserFactory()
    other_user = UserFactory()
    user_insight = StudyInsightFactory(session__owner=user)
    StudyInsightFactory(session__owner=other_user)
    request = RequestFactory().get(reverse("insights:list"))
    request.user = user
    view = InsightListView()
    view.request = request

    assert list(view.get_queryset()) == [user_insight]


def test_view_rejects_get_requests_for_generation(client) -> None:
    """Insight generation should require POST."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session, content="Django testing workflow.")
    client.force_login(session.owner)

    response = client.get(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
    )

    assert response.status_code == 405
    assert StudyInsight.objects.count() == 0


def test_view_redirects_anonymous_users_to_login(client) -> None:
    """Anonymous users should not be able to generate insights."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session, content="Django testing workflow.")

    response = client.post(
        reverse("insights:generate", kwargs={"session_id": session.pk}),
    )

    assert response.status_code == 302
    assert response["Location"].startswith(f"{reverse('users:login')}?next=")
    assert StudyInsight.objects.count() == 0


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
