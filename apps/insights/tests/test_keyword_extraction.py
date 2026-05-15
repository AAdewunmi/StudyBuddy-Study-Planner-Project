"""Tests for deterministic keyword extraction."""

from __future__ import annotations

from apps.insights.nlp.keyword_extraction import extract_keywords
from apps.insights.nlp.text_processing import (
    meaningful_tokens,
    normalise_text,
    source_text_hash,
    tokenize,
)


def test_normalise_text_lowercases_and_collapses_whitespace() -> None:
    """Normalisation should produce stable lowercase text."""
    result = normalise_text("  Django    Testing\nWorkflow  ")

    assert result == "django testing workflow"


def test_tokenize_removes_punctuation() -> None:
    """Tokenisation should keep alphanumeric terms and remove punctuation."""
    result = tokenize("Django, pytest, and PostgreSQL!")

    assert result == ["django", "pytest", "and", "postgresql"]


def test_meaningful_tokens_filters_stop_words_and_short_terms() -> None:
    """Stop words and short terms should not drive keyword extraction."""
    result = meaningful_tokens("The API is on and the UI is in sync.")

    assert result == ["api", "sync"]


def test_extract_keywords_ranks_repeated_terms_first() -> None:
    """Repeated meaningful terms should rank ahead of less frequent terms."""
    result = extract_keywords(
        "Django testing testing pytest Django testing database.",
        limit=3,
    )

    assert result == ["testing", "django", "database"]


def test_extract_keywords_uses_alphabetical_order_for_ties() -> None:
    """Tie-breaking should be deterministic."""
    result = extract_keywords("zebra alpha beta zebra alpha beta", limit=3)

    assert result == ["alpha", "beta", "zebra"]


def test_extract_keywords_respects_limit() -> None:
    """The keyword limit should control result length."""
    result = extract_keywords(
        "django pytest postgres docker templates bootstrap views models",
        limit=4,
    )

    assert result == ["bootstrap", "django", "docker", "models"]


def test_extract_keywords_returns_empty_list_for_empty_input() -> None:
    """Empty or meaningless input should return no keywords."""
    assert extract_keywords("") == []
    assert extract_keywords("and the of to") == []


def test_source_text_hash_is_stable_for_equivalent_whitespace() -> None:
    """Normalised source text should produce stable hashes."""
    first_hash = source_text_hash("Django    testing workflow")
    second_hash = source_text_hash(" django testing   workflow ")

    assert first_hash == second_hash