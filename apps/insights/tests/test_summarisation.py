"""Tests for deterministic extractive summaries."""

from __future__ import annotations

import pytest

from apps.insights.nlp import summarisation
from apps.insights.nlp.summarisation import LOW_INFORMATION_SUMMARY, summarise_text
from apps.insights.nlp.text_processing import split_sentences


def test_summarise_text_selects_high_signal_source_sentence() -> None:
    """Summary should favour sentences containing repeated meaningful terms."""
    text = (
        "Today I opened the dashboard. "
        "Django testing confirms that Django views and Django forms work. "
        "I also reviewed a short note."
    )

    result = summarise_text(text, max_sentences=1)

    assert result == "Django testing confirms that Django views and Django forms work."


def test_summarise_text_preserves_source_order_after_scoring() -> None:
    """Selected sentences should be returned in original reading order."""
    text = (
        "Database database transactions keep study notes consistent. "
        "Django forms validate study sessions. "
        "Database database constraints protect ownership rules."
    )

    result = summarise_text(text, max_sentences=2)

    assert result == (
        "Database database transactions keep study notes consistent. "
        "Database database constraints protect ownership rules."
    )


def test_summarise_text_uses_only_user_note_sentences() -> None:
    """Every summary sentence should be copied from the user's own notes."""
    text = (
        "Photosynthesis photosynthesis uses chlorophyll to convert light into glucose. "
        "Cell respiration releases stored energy during revision. "
        "Photosynthesis depends on carbon dioxide and water."
    )

    result = summarise_text(text, max_sentences=2)

    assert result == (
        "Photosynthesis photosynthesis uses chlorophyll to convert light into glucose. "
        "Photosynthesis depends on carbon dioxide and water."
    )
    source_sentences = split_sentences(text)
    summary_sentences = split_sentences(result)
    assert summary_sentences
    assert all(sentence in source_sentences for sentence in summary_sentences)
    assert "mitochondria" not in result


def test_summarise_text_handles_empty_input() -> None:
    """Empty input should return the low-information summary."""
    assert summarise_text("") == LOW_INFORMATION_SUMMARY


def test_summarise_text_handles_low_information_input() -> None:
    """Low-signal input should not be presented as a useful summary."""
    assert summarise_text("and the of to") == LOW_INFORMATION_SUMMARY
    assert summarise_text("AI ML UX") == LOW_INFORMATION_SUMMARY
    assert summarise_text("Useful content exists.", max_sentences=0) == (
        LOW_INFORMATION_SUMMARY
    )


def test_summarise_text_handles_empty_keyword_result(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A defensive empty keyword result should produce a low-information summary."""
    monkeypatch.setattr(
        summarisation,
        "extract_keywords",
        lambda _text, limit=8: [],
    )

    assert summarise_text("Biology notes contain useful context.") == (
        LOW_INFORMATION_SUMMARY
    )


def test_summarise_text_handles_unscored_sentences(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Sentences with no keyword overlap should not be presented as useful."""
    monkeypatch.setattr(
        summarisation,
        "extract_keywords",
        lambda _text, limit=8: ["absent"],
    )

    assert summarise_text("Biology notes contain useful context.") == (
        LOW_INFORMATION_SUMMARY
    )
