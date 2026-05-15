"""Tests for deterministic NLP text processing helpers."""

from __future__ import annotations

from apps.insights.nlp.text_processing import split_sentences


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
    3. Compare integration methods
    """

    assert split_sentences(text) == [
        "Goals:",
        "Review calculus limits",
        "Practice derivative rules",
        "Compare integration methods",
    ]


def test_split_sentences_keeps_abbreviations_and_decimals_together() -> None:
    """Known abbreviations and decimals do not create false boundaries."""
    text = (
        "Dr. Smith used e.g. 3.14 in examples. "
        "Students solved 2.5 practice sets."
    )

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
