"""Tests for deterministic insight explanations."""

from __future__ import annotations

from apps.insights.nlp.explanations import build_explanation


def test_build_explanation_handles_low_information_text() -> None:
    """Blank or low-signal notes should ask the user for more detail."""
    result = build_explanation("", [], confidence=0)

    assert result == (
        "This insight has low confidence because the session does not "
        "contain enough note text to analyse. Add more detailed notes and "
        "generate the insight again."
    )


def test_build_explanation_includes_confidence_label_and_term_count() -> None:
    """Meaningful notes should explain confidence using analysed term count."""
    text = "Django testing confirms reliable session workflows."

    result = build_explanation(text, ["django", "testing"], confidence=80)

    assert result.startswith("This high confidence insight")
    assert "6 meaningful terms" in result


def test_build_explanation_describes_deterministic_keyword_ranking() -> None:
    """Explanations should tell users how keywords were selected."""
    result = build_explanation(
        "Django testing confirms reliable session workflows.",
        ["django", "testing"],
        confidence=60,
    )

    assert "ranked by term frequency with deterministic tie-breaking" in result


def test_build_explanation_describes_source_sentence_summary() -> None:
    """Explanations should state that summaries use source note sentences."""
    result = build_explanation(
        "Django testing confirms reliable session workflows.",
        ["django", "testing"],
        confidence=60,
    )

    assert "uses sentences from the original notes" in result
    assert "rather than generated claims" in result


def test_build_explanation_lists_detected_keywords() -> None:
    """Detected keywords should be visible in the explanation."""
    result = build_explanation(
        "Django testing confirms reliable session workflows.",
        ["django", "testing"],
        confidence=60,
    )

    assert result.endswith("Detected keywords: django, testing.")


def test_build_explanation_handles_missing_keywords() -> None:
    """Explanations should be honest when there are no strong repeated terms."""
    result = build_explanation(
        "Django testing confirms reliable session workflows.",
        [],
        confidence=45,
    )

    assert result.startswith("This medium confidence insight")
    assert result.endswith("Detected keywords: no strong repeated terms.")
