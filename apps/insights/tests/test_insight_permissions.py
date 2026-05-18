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


def test_list_view_renders_only_authenticated_users_insights(client) -> None:
    """The insight dashboard should render only insights owned through sessions."""
    user = UserFactory()
    other_user = UserFactory()
    user_insight = StudyInsightFactory(
        session__owner=user,
        session__title="Owned insight session",
        summary="Owned deterministic summary.",
        keywords=["django", "testing"],
        confidence=84,
        explanation="Owned explanation for generated insight.",
    )
    StudyInsightFactory(
        session__owner=other_user,
        session__title="Hidden insight session",
        summary="Hidden deterministic summary.",
    )
    client.force_login(user)

    response = client.get(reverse("insights:list"))
    content = response.content.decode()

    assert response.status_code == 200
    assert list(response.context["insights"]) == [user_insight]
    assert "Owned insight session" in content
    assert "Owned deterministic summary." in content
    assert "django" in content
    assert "84%" in content
    assert "Owned explanation for generated insight." in content
    assert "Hidden insight session" not in content
    assert "Hidden deterministic summary." not in content


def test_list_view_requires_login(client) -> None:
    """Anonymous users should be redirected before viewing insights."""
    response = client.get(reverse("insights:list"))

    assert response.status_code == 302
    assert response["Location"].startswith(f"{reverse('users:login')}?next=")


def test_list_view_renders_empty_state(client) -> None:
    """Users without generated insights should see the empty dashboard state."""
    user = UserFactory()
    client.force_login(user)

    response = client.get(reverse("insights:list"))

    assert response.status_code == 200
    assert b"Generate an insight from a study session." in response.content


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
