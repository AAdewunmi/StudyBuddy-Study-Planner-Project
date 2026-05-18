"""Tests for the insights dashboard."""

from __future__ import annotations

import pytest
from django.urls import reverse

from apps.insights.factories import StudyInsightFactory
from apps.users.factories import UserFactory

pytestmark = pytest.mark.django_db


def test_insights_dashboard_requires_authentication(client) -> None:
    """Anonymous users should be redirected to login."""
    response = client.get(reverse("insights:list"))

    assert response.status_code == 302
    assert response["Location"].startswith(f"{reverse('users:login')}?next=")


def test_insights_dashboard_shows_user_owned_insights(client) -> None:
    """Authenticated users should see their own generated insights."""
    insight = StudyInsightFactory(
        summary="Django testing improves review.",
        confidence=84,
    )
    client.force_login(insight.session.owner)

    response = client.get(reverse("insights:list"))

    assert response.status_code == 200
    assert b"Django testing improves review." in response.content
    assert b"84%" in response.content


def test_insights_dashboard_hides_other_users_insights(client) -> None:
    """Insights must be scoped to the authenticated user."""
    own_insight = StudyInsightFactory(summary="Visible user insight.")
    other_user = UserFactory()
    StudyInsightFactory(summary="Hidden user insight", session__owner=other_user)

    client.force_login(own_insight.session.owner)
    response = client.get(reverse("insights:list"))

    assert response.status_code == 200
    assert b"Visible user insight." in response.content
    assert b"Hidden user insight" not in response.content


def test_insights_dashboard_displays_empty_state(client) -> None:
    """A user without insights should receive a useful empty state."""
    user = UserFactory()
    client.force_login(user)

    response = client.get(reverse("insights:list"))

    assert response.status_code == 200
    assert b"Generate an insight from a study session." in response.content
