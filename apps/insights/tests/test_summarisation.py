"""Tests for deterministic extractive summaries."""

from __future__ import annotations

from apps.insights.nlp.summarisation import LOW_INFORMATION_SUMMARY, summarise_text


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
        "Database transactions keep study notes consistent. "
        "Django forms validate study sessions. "
        "Database constraints protect ownership rules."
    )

    result = summarise_text(text, max_sentences=2)

    assert result == (
        "Database transactions keep study notes consistent. "
        "Database constraints protect ownership rules."
    )


def test_summarise_text_handles_empty_input() -> None:
    """Empty input should return the low-information summary."""
    assert summarise_text("") == LOW_INFORMATION_SUMMARY