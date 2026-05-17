"""Explanation builders for deterministic NLP insights."""

from __future__ import annotations

from apps.insights.nlp.confidence import confidence_label
from apps.insights.nlp.text_processing import meaningful_tokens


def build_explanation(
    text: str | None,
    keywords: list[str],
    confidence: int,
) -> str:
    """Build a plain-English explanation for a generated insight.

    Args:
        text: Raw source text.
        keywords: Extracted keyword list.
        confidence: Rule-based confidence score.

    Returns:
        Explanation suitable for display in the product UI.
    """
    tokens = meaningful_tokens(text)
    label = confidence_label(confidence)

    if not tokens:
        return (
            "This insight has low confidence because the session does not "
            "contain enough note text to analyse. Add more detailed notes and "
            "generate the insight again."
        )

    keyword_text = ", ".join(keywords) if keywords else "no strong repeated terms"

    return (
        f"This {label.lower()} confidence insight was generated using "
        f"{len(tokens)} meaningful terms from the session notes. Keywords were "
        f"ranked by term frequency with deterministic tie-breaking. The summary "
        f"uses sentences from the original notes rather than generated claims. "
        f"Detected keywords: {keyword_text}."
    )