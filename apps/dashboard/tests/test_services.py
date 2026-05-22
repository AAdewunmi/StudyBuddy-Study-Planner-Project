"""Service tests for dashboard context composition."""

from __future__ import annotations

import pytest

from apps.dashboard.services import build_dashboard_context
from apps.insights.factories import StudyInsightFactory
from apps.roles.factories import RoleFactory
from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.sessions.models import StudySession
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


def test_build_dashboard_context_returns_admin_platform_metrics() -> None:
    """Admin users receive operational platform metrics."""
    admin_user = CustomUserFactory(email="admin.dashboard@example.com")
    admin_role = RoleFactory(admin=True)
    student_role = RoleFactory(student=True)
    tutor_role = RoleFactory(tutor=True)
    admin_user.studybuddy_roles.add(admin_role)
    student = CustomUserFactory(email="student.dashboard@example.com")
    tutor = CustomUserFactory(email="tutor.dashboard@example.com")
    unassigned_user = CustomUserFactory(email="unassigned.dashboard@example.com")
    student.studybuddy_roles.add(student_role)
    tutor.studybuddy_roles.add(tutor_role)
    completed_session = StudySessionFactory(
        owner=student,
        status=StudySession.Status.COMPLETED,
        duration_minutes=80,
    )
    StudyNoteFactory(session=completed_session)
    StudyInsightFactory(
        session=completed_session,
        confidence=90,
        keywords=["django", "testing", "django"],
    )

    context = build_dashboard_context(admin_user)
    platform_metrics = context["platform_metrics"]

    assert context["dashboard_variant"] == "admin"
    assert platform_metrics.total_users == 4
    assert platform_metrics.total_students == 1
    assert platform_metrics.total_tutors == 1
    assert platform_metrics.total_admins == 1
    assert platform_metrics.users_without_roles == 1
    assert platform_metrics.total_sessions == 1
    assert platform_metrics.completed_sessions == 1
    assert platform_metrics.total_study_minutes == 80
    assert platform_metrics.total_notes == 1
    assert platform_metrics.total_insights == 1
    assert platform_metrics.average_confidence == 90
    assert platform_metrics.sessions_with_insights == 1
    assert platform_metrics.sessions_without_insights == 0
    assert platform_metrics.top_keywords[0].label == "django"
    assert platform_metrics.top_keywords[0].count == 2
    assert unassigned_user in platform_metrics.recent_users
