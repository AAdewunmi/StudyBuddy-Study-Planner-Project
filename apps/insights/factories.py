"""factory_boy factories for insight tests."""

from __future__ import annotations

import factory

from apps.insights.models import StudyInsight
from apps.sessions.factories import StudySessionFactory


class StudyInsightFactory(factory.django.DjangoModelFactory):
    """Create persisted study insight instances for tests."""

    class Meta:
        """Factory metadata."""

        model = StudyInsight

    session = factory.SubFactory(StudySessionFactory)
    summary = "Django tests confirm the study workflow behaves as expected."
    keywords = factory.LazyFunction(lambda: ["django", "tests", "workflow"])
    confidence = 76
    explanation = (
        "This insight was generated with deterministic keyword extraction, "
        "extractive summarisation, and rule-based confidence scoring."
    )
    source_hash = factory.Sequence(lambda number: f"{number:064x}"[-64:])
