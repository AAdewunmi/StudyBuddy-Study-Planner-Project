"""Service tests for dashboard context composition."""

from __future__ import annotations

import pytest

from apps.dashboard.services import build_dashboard_context
from apps.roles.factories import RoleFactory
from apps.sessions.factories import StudySessionFactory
from apps.users.factories import CustomUserFactory

pytestmark = pytest.mark.django_db


def test_build_dashboard_context_returns_template_ready_user_context() -> None:
    """Dashboard context includes roles and user-scoped session activity."""
    user = CustomUserFactory(email="dashboard.context@example.com")
    later_role = RoleFactory(slug="z-role", display_name="Z Role")
    earlier_role = RoleFactory(slug="a-role", display_name="A Role")
    user.studybuddy_roles.add(later_role, earlier_role)
    session = StudySessionFactory(owner=user, duration_minutes=50)
    StudySessionFactory(duration_minutes=90)

    context = build_dashboard_context(user)

    assert list(context["roles"]) == [earlier_role, later_role]
    assert context["metrics"].total_sessions == 1
    assert context["metrics"].total_minutes == 50
    assert context["recent_activity"] == [session]
