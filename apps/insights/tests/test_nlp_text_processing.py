"""Tests for deterministic NLP text processing helpers."""

from __future__ import annotations

import hashlib

from apps.insights.nlp.text_processing import (
    meaningful_tokens,
    normalise_text,
    source_text_hash,
    split_sentences,
    tokenize,
)


def test_normalise_text_lowercases_and_collapses_whitespace() -> None:
    """Normalised text is stable for hashing and downstream analysis."""
    assert normalise_text("  Photosynthesis\n\tNeeds   LIGHT  ") == (
        "photosynthesis needs light"
    )
    assert normalise_text(None) == ""


def test_tokenize_extracts_lowercase_alphanumeric_terms() -> None:
    """Tokenisation keeps deterministic alphanumeric terms in source order."""
    assert tokenize("AI-101: Review CO2 + H2O reactions.") == [
        "ai",
        "101",
        "review",
        "co2",
        "h2o",
        "reactions",
    ]


def test_meaningful_tokens_filters_stop_words_and_short_terms() -> None:
    """Meaningful tokens exclude stop words and short low-signal terms."""
    assert meaningful_tokens("The AI plan is to review biology notes") == [
        "plan",
        "review",
        "biology",
        "notes",
    ]


def test_source_text_hash_uses_normalised_text_sha256() -> None:
    """Source hashes are valid SHA-256 digests of normalised text."""
    expected = hashlib.sha256(b"algebra notes").hexdigest()

    assert source_text_hash("  Algebra\nNotes  ") == expected
    assert len(source_text_hash("Algebra notes")) == 64


def test_split_sentences_handles_basic_sentence_punctuation() -> None:
    """Sentences split on common sentence-ending punctuation."""
    text = "Read the notes carefully. What changed? Practice again!"

    assert split_sentences(text) == [
        "Read the notes carefully.",
        "What changed?",
        "Practice again!",
    ]


def test_split_sentences_handles_note_list_items() -> None:
    """Study-note list items are treated as separate source units."""
    text = """
    Goals:
    - Review calculus limits
    - Practice derivative rules
    * Revisit chain rule examples
    3. Compare integration methods
    4) Check substitution steps
    """

    assert split_sentences(text) == [
        "Goals:",
        "Review calculus limits",
        "Practice derivative rules",
        "Revisit chain rule examples",
        "Compare integration methods",
        "Check substitution steps",
    ]


def test_split_sentences_keeps_abbreviations_and_decimals_together() -> None:
    """Known abbreviations and decimals do not create false boundaries."""
    text = "Dr. Smith used e.g. 3.14 in examples. " "Students solved 2.5 practice sets."

    assert split_sentences(text) == [
        "Dr. Smith used e.g. 3.14 in examples.",
        "Students solved 2.5 practice sets.",
    ]


def test_split_sentences_preserves_source_order_across_paragraphs() -> None:
    """Paragraph and sentence ordering follows the original note text."""
    text = """
    First paragraph has context. It has another point.

    Second paragraph adds examples.
    Final fragment without punctuation
    """

    assert split_sentences(text) == [
        "First paragraph has context.",
        "It has another point.",
        "Second paragraph adds examples.",
        "Final fragment without punctuation",
    ]


def test_split_sentences_returns_empty_list_for_blank_text() -> None:
    """Blank text has no source sentences."""
    assert split_sentences(None) == []
    assert split_sentences(" \n\t ") == []
