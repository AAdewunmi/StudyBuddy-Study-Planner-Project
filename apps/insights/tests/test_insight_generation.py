"""Integration tests for insight generation and persistence."""

from __future__ import annotations

import pytest

from apps.insights.models import StudyInsight
from apps.insights.services import generate_insight_for_session
from apps.sessions.factories import StudyNoteFactory, StudySessionFactory

pytestmark = pytest.mark.django_db


def test_generate_insight_persists_analysis_result() -> None:
    """Generating an insight should persist summary, keywords, and confidence."""
    session = StudySessionFactory()
    StudyNoteFactory(
        session=session,
        content=(
            "Django testing improves confidence. "
            "Django views, forms, and database tests protect the workflow."
        ),
    )

    result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    assert result.created is True
    assert StudyInsight.objects.count() == 1
    assert result.insight.summary
    assert "django" in result.insight.keywords
    assert result.insight.confidence > 0
    assert result.insight.explanation


def test_generate_insight_uses_source_hash() -> None:
    """Persisted insights should include a stable source hash."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session, content="PostgreSQL persistence matters.")

    result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    assert len(result.insight.source_hash) == 64


def test_generate_insight_reuses_existing_result_for_unchanged_notes() -> None:
    """Running generation twice against unchanged notes should be idempotent."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session, content="Testing testing database workflow.")

    first = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )
    second = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    assert first.created is True
    assert second.created is False
    assert first.insight.pk == second.insight.pk
    assert StudyInsight.objects.count() == 1


def test_generate_insight_creates_new_result_when_notes_change() -> None:
    """Changing source notes should produce a new source hash and insight."""
    session = StudySessionFactory()
    StudyNoteFactory(session=session, content="Initial Django notes.")

    first = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    StudyNoteFactory(session=session, content="Additional pytest database notes.")

    second = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    assert first.insight.source_hash != second.insight.source_hash
    assert StudyInsight.objects.count() == 2


def test_generate_insight_handles_session_without_notes() -> None:
    """A session without notes should still create an honest low-confidence result."""
    session = StudySessionFactory()

    result = generate_insight_for_session(
        session=session,
        requested_by=session.owner,
    )

    assert result.insight.confidence == 0
    assert "not enough study note content" in result.insight.summary.lower()