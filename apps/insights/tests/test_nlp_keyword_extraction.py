"""Tests for deterministic NLP keyword extraction."""

from __future__ import annotations

from apps.insights.nlp.keyword_extraction import extract_keywords


def test_extract_keywords_ranks_by_frequency_then_alphabetically() -> None:
    """Keyword ranking is deterministic and explainable."""
    text = (
        "Biology chemistry biology algebra chemistry biology " "revision algebra tests."
    )

    assert extract_keywords(text, limit=4) == [
        "biology",
        "algebra",
        "chemistry",
        "revision",
    ]


def test_extract_keywords_caps_results_by_limit() -> None:
    """Keyword output respects the configured limit."""
    text = "calculus algebra physics chemistry biology geometry"

    assert extract_keywords(text, limit=3) == [
        "algebra",
        "biology",
        "calculus",
    ]


def test_extract_keywords_returns_empty_list_for_non_positive_limit() -> None:
    """Non-positive limits produce no keywords."""
    assert extract_keywords("biology biology chemistry", limit=0) == []
    assert extract_keywords("biology biology chemistry", limit=-1) == []


def test_extract_keywords_returns_empty_list_without_meaningful_tokens() -> None:
    """Blank, stop-word-only, and short-token input has no keywords."""
    assert extract_keywords(None) == []
    assert extract_keywords("the and of to") == []
    assert extract_keywords("AI ML UX") == []
