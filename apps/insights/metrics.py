"""Template-ready metrics for the insights dashboard."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from django.db.models import Avg

from apps.insights.models import StudyInsight
from apps.insights.selectors import get_user_insights
from apps.sessions.selectors import get_sessions_for_user


@dataclass(frozen=True)
class KeywordMetric:
    """Keyword frequency for dashboard display."""

    label: str
    count: int


@dataclass(frozen=True)
class InsightMetrics:
    """User-scoped insight metrics for templates."""

    total_insights: int
    average_confidence: int
    sessions_with_insights: int
    sessions_without_insights: int
    top_keywords: list[KeywordMetric]
    recent_insights: list[StudyInsight]


def build_insight_metrics_for_user(user: Any) -> InsightMetrics:
    """Build insight dashboard metrics scoped to the supplied user."""
    insights = get_user_insights(user)
    sessions = get_sessions_for_user(user)
    total_sessions = sessions.count()
    sessions_with_insights = insights.values("session_id").distinct().count()
    average_confidence = insights.aggregate(average=Avg("confidence"))["average"] or 0

    return InsightMetrics(
        total_insights=insights.count(),
        average_confidence=round(average_confidence),
        sessions_with_insights=sessions_with_insights,
        sessions_without_insights=max(total_sessions - sessions_with_insights, 0),
        top_keywords=_build_top_keywords(insights),
        recent_insights=list(insights[:3]),
    )


def _build_top_keywords(insights: Any, limit: int = 8) -> list[KeywordMetric]:
    """Return keyword counts from persisted insight JSON."""
    keyword_counts: dict[str, int] = {}

    for keywords in insights.values_list("keywords", flat=True):
        for keyword in keywords or []:
            normalised_keyword = keyword.strip().lower()
            if normalised_keyword:
                keyword_counts[normalised_keyword] = (
                    keyword_counts.get(normalised_keyword, 0) + 1
                )

    return [
        KeywordMetric(label=keyword, count=count)
        for keyword, count in sorted(
            keyword_counts.items(),
            key=lambda item: (-item[1], item[0]),
        )[:limit]
    ]
