"""Tests for deterministic confidence scoring."""

from __future__ import annotations

from apps.insights.nlp.confidence import confidence_label, score_confidence


def test_score_confidence_returns_zero_for_empty_text() -> None:
    """No note content should produce zero confidence."""
    result = score_confidence("", [], "There is not enough content.")

    assert result == 0


def test_score_confidence_stays_within_bounds() -> None:
    """Confidence should always be a percentage-style bounded value."""
    text = " ".join(["django testing database workflow"] * 20)

    result = score_confidence(
        text,
        ["django", "testing", "database", "workflow"],
        "Django testing database workflow.",
    )

    assert 0 <= result <= 100


def test_score_confidence_increases_for_richer_content() -> None:
    """Richer text with keywords and summary should score higher."""
    weak = score_confidence("Django.", ["django"], "Django.")
    strong = score_confidence(
        (
            "Django testing confirms reliable session workflows. "
            "Database-backed notes improve review quality. "
            "Pytest verifies permissions and persistence behaviour."
        ),
        ["django", "testing", "database", "pytest", "permissions"],
        "Django testing confirms reliable session workflows.",
    )

    assert strong > weak


def test_confidence_label_maps_score_to_user_facing_label() -> None:
    """Confidence labels should be simple and predictable."""
    assert confidence_label(20) == "Low"
    assert confidence_label(60) == "Medium"
    assert confidence_label(90) == "High"