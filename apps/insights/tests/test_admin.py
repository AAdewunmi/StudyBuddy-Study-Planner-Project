"""Admin tests for generated study insights."""

from __future__ import annotations

import pytest
from django.contrib import admin

from apps.insights.admin import StudyInsightAdmin
from apps.insights.factories import StudyInsightFactory
from apps.insights.models import StudyInsight
from apps.users.factories import CustomUserFactory

pytestmark = pytest.mark.django_db


def test_study_insight_admin_session_owner_returns_owner_email() -> None:
    """Insight admin exposes ownership through the parent study session."""
    user = CustomUserFactory(email="insight.owner@example.com")
    insight = StudyInsightFactory(session__owner=user)
    insight_admin = StudyInsightAdmin(StudyInsight, admin.site)

    assert insight_admin.session_owner(insight) == "insight.owner@example.com"


def test_study_insight_admin_keywords_preview_is_compact() -> None:
    """Insight admin displays only the first five keywords."""
    insight = StudyInsightFactory(
        keywords=["django", "tests", "sessions", "notes", "insights", "extra"]
    )
    insight_admin = StudyInsightAdmin(StudyInsight, admin.site)

    assert insight_admin.keywords_preview(insight) == (
        "django, tests, sessions, notes, insights"
    )
