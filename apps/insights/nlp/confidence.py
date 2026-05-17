"""Rule-based confidence scoring for deterministic study insights."""

from __future__ import annotations

from apps.insights.nlp.text_processing import meaningful_tokens


def score_confidence(text: str | None, keywords: list[str], summary: str) -> int:
    """Score confidence for a generated insight.

    The score is a transparent quality heuristic, not a probability or model
    intelligence signal. It reflects whether the source text contains enough
    meaningful content to support a useful extractive summary and keyword set.

    Args:
        text: Raw source text.
        keywords: Extracted keyword list.
        summary: Generated summary text.

    Returns:
        Integer confidence score from 0 to 100.
    """
    tokens = meaningful_tokens(text)

    if not tokens:
        return 0

    score = 20

    if len(tokens) >= 20:
        score += 25
    elif len(tokens) >= 10:
        score += 15
    else:
        score += 5

    if len(set(tokens)) >= 10:
        score += 15
    elif len(set(tokens)) >= 5:
        score += 8

    if len(keywords) >= 5:
        score += 20
    elif len(keywords) >= 3:
        score += 12
    elif keywords:
        score += 5

    if summary and "not enough study note content" not in summary.lower():
        score += 20

    return max(0, min(score, 100))


def confidence_label(score: int) -> str:
    """Return a user-facing confidence label.

    Args:
        score: Confidence score from 0 to 100.

    Returns:
        One of ``Low``, ``Medium``, or ``High``.
    """
    if score >= 75:
        return "High"

    if score >= 45:
        return "Medium"

    return "Low"
