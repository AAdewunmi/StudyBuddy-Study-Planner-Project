"""Deterministic keyword extraction for study notes."""

from __future__ import annotations

from collections import Counter

from apps.insights.nlp.text_processing import meaningful_tokens


def extract_keywords(text: str | None, limit: int = 8) -> list[str]:
    """Extract ranked keywords from note text.

    Ranking is deterministic:
    1. Higher term frequency first.
    2. Alphabetical order for ties.

    Args:
        text: Raw note text.
        limit: Maximum number of keywords to return.

    Returns:
        Ranked keyword strings.
    """
    if limit <= 0:
        return []

    tokens = meaningful_tokens(text)
    if not tokens:
        return []

    counts = Counter(tokens)
    ranked_terms = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    return [term for term, _count in ranked_terms[:limit]]
