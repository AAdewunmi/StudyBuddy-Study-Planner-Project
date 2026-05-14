"""Tests for the StudyInsight model."""

from __future__ import annotations

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError

from apps.insights.factories import StudyInsightFactory
from apps.insights.models import StudyInsight
from apps.sessions.factories import StudySessionFactory

pytestmark = pytest.mark.django_db


def test_study_insight_persists_with_explainable_fields() -> None:
    """A generated insight stores the fields required for explainable output."""
    insight = StudyInsightFactory(
        summary="Testing confirms that session workflows are reliable.",
        keywords=["testing", "session", "workflow"],
        confidence=82,
        explanation="Keywords are ranked by deterministic term frequency.",
    )

    assert insight.pk is not None
    assert insight.summary.startswith("Testing confirms")
    assert insight.keywords == ["testing", "session", "workflow"]
    assert insight.confidence == 82
    assert len(insight.source_hash) == 64


def test_study_insight_inherits_ownership_through_session() -> None:
    """Insight ownership is resolved through the parent study session."""
    session = StudySessionFactory()

    insight = StudyInsightFactory(session=session)

    assert insight.session == session
    assert insight.session.owner == session.owner


def test_study_insight_rejects_invalid_keyword_shape() -> None:
    """Keywords must be stored as a list of strings."""
    insight = StudyInsightFactory.build(keywords={"django": 3})

    with pytest.raises(ValidationError):
        insight.full_clean()


def test_study_insight_is_unique_for_session_and_source_hash() -> None:
    """The same source text should not create duplicate insight rows."""
    insight = StudyInsightFactory()

    with pytest.raises((IntegrityError, ValidationError)):
        StudyInsight.objects.create(
            session=insight.session,
            summary="Duplicate insight.",
            keywords=["duplicate"],
            confidence=60,
            explanation="Duplicate source hash should be rejected.",
            source_hash=insight.source_hash,
        )
