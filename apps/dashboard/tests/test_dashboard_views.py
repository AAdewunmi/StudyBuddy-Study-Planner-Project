"""Integration tests for the dashboard views."""

from __future__ import annotations

import pytest
from django.urls import reverse

from apps.roles.factories import RoleFactory
from apps.sessions.factories import StudySessionFactory
from apps.users.factories import CustomUserFactory


@pytest.mark.django_db
def test_dashboard_redirects_anonymous_users(client):
    """Anonymous users are redirected to login before viewing the dashboard."""
    response = client.get(reverse("dashboard:index"))

    assert response.status_code == 302
    assert response["Location"].startswith(f"{reverse('users:login')}?next=")


@pytest.mark.django_db
def test_dashboard_renders_for_authenticated_user(client):
    """Authenticated users can view the dashboard shell and empty state."""
    user = CustomUserFactory()
    client.force_login(user)

    response = client.get(reverse("dashboard:index"))

    assert response.status_code == 200
    assert b"Your study dashboard" in response.content
    assert b"No study sessions yet" in response.content
    assert b"No product roles have been assigned yet." in response.content


@pytest.mark.django_db
def test_dashboard_displays_roles_from_view_context(client):
    """Dashboard role display is presentation-only context from the view."""
    user = CustomUserFactory()
    role = RoleFactory(slug="learner", display_name="Learner")
    user.studybuddy_roles.add(role)
    client.force_login(user)

    response = client.get(reverse("dashboard:index"))

    assert response.status_code == 200
    assert list(response.context["roles"]) == [role]
    assert b"Learner" in response.content


@pytest.mark.django_db
def test_dashboard_uses_user_scoped_service_context(client):
    """Dashboard context includes session metrics from the dashboard service."""
    user = CustomUserFactory()
    StudySessionFactory(owner=user, duration_minutes=60)
    StudySessionFactory(duration_minutes=120)
    client.force_login(user)

    response = client.get(reverse("dashboard:index"))

    assert response.status_code == 200
    assert response.context["metrics"].total_sessions == 1
    assert response.context["metrics"].total_minutes == 60
    assert len(response.context["recent_activity"]) == 1
