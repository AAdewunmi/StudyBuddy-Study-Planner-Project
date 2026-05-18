"""Application services for generating persisted study insights."""

from __future__ import annotations

from dataclasses import dataclass

from django.core.exceptions import FieldError, PermissionDenied
from django.db import transaction

from apps.insights.models import StudyInsight
from apps.insights.nlp.confidence import score_confidence
from apps.insights.nlp.explanations import build_explanation
from apps.insights.nlp.keyword_extraction import extract_keywords
from apps.insights.nlp.summarisation import summarise_text
from apps.insights.nlp.text_processing import source_text_hash
from apps.sessions.models import StudyNote


@dataclass(frozen=True)
class InsightGenerationResult:
    """Return value for insight generation."""

    insight: StudyInsight
    created: bool


def get_session_note_text(session: object) -> str:
    """Return combined note text for a study session.

    Args:
        session: Study session instance.

    Returns:
        Combined note content in deterministic order.
    """
    notes_manager = getattr(session, "notes", None)

    if notes_manager is not None:
        notes = notes_manager.all()
    else:
        notes = StudyNote.objects.filter(session=session)

    try:
        notes = notes.order_by("created_at", "id")
    except FieldError:
        # Older Sprint 2 builds may not include created_at on StudyNote.
        notes = notes.order_by("id")

    content_values = []
    for note in notes:
        content = getattr(note, "content", "")
        if content:
            content_values.append(content.strip())

    return "\n\n".join(value for value in content_values if value)


def analyse_note_text(text: str) -> dict[str, object]:
    """Run the deterministic NLP pipeline over source note text.

    Args:
        text: Combined note content.

    Returns:
        Dictionary containing summary, keywords, confidence, explanation,
        and source hash.
    """
    keywords = extract_keywords(text)
    summary = summarise_text(text)
    confidence = score_confidence(text, keywords, summary)
    explanation = build_explanation(text, keywords, confidence)

    return {
        "summary": summary,
        "keywords": keywords,
        "confidence": confidence,
        "explanation": explanation,
        "source_hash": source_text_hash(text),
    }


@transaction.atomic
def generate_insight_for_session(
    *,
    session: object,
    requested_by: object,
) -> InsightGenerationResult:
    """Generate or reuse a persisted insight for a study session.

    Args:
        session: Study session to analyse.
        requested_by: Authenticated user requesting the insight.

    Returns:
        InsightGenerationResult with the insight and creation flag.

    Raises:
        PermissionDenied: If the requesting user does not own the session.
    """
    session_owner = getattr(session, "owner", None)

    if session_owner != requested_by:
        raise PermissionDenied("You can only generate insights for your own sessions.")

    note_text = get_session_note_text(session)
    payload = analyse_note_text(note_text)

    insight, created = StudyInsight.objects.get_or_create(
        session=session,
        source_hash=payload["source_hash"],
        defaults={
            "summary": payload["summary"],
            "keywords": payload["keywords"],
            "confidence": payload["confidence"],
            "explanation": payload["explanation"],
        },
    )

    return InsightGenerationResult(insight=insight, created=created)
