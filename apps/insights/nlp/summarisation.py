"""Extractive summary generation for study notes."""

from __future__ import annotations

from collections import Counter

from apps.insights.nlp.keyword_extraction import extract_keywords
from apps.insights.nlp.text_processing import meaningful_tokens, split_sentences

LOW_INFORMATION_SUMMARY = (
    "There is not enough study note content to generate a useful summary yet."
)


def summarise_text(text: str | None, max_sentences: int = 2) -> str:
    """Create a deterministic extractive summary.

    The function selects source sentences that contain high-frequency
    meaningful terms. It never invents new facts because every selected
    sentence comes from the user's notes.

    Args:
        text: Raw note text.
        max_sentences: Maximum number of source sentences to include.

    Returns:
        Summary text.
    """
    if max_sentences <= 0:
        return LOW_INFORMATION_SUMMARY

    sentences = split_sentences(text)
    if not sentences:
        return LOW_INFORMATION_SUMMARY

    meaningful_terms = meaningful_tokens(text)
    if not meaningful_terms:
        return LOW_INFORMATION_SUMMARY

    keywords = extract_keywords(text, limit=8)
    token_counts = Counter(meaningful_terms)

    if not keywords:
        return LOW_INFORMATION_SUMMARY

    keyword_set = set(keywords)
    scored_sentences: list[tuple[int, int, str]] = []

    for index, sentence in enumerate(sentences):
        sentence_tokens = meaningful_tokens(sentence)
        score = sum(
            token_counts[token] for token in sentence_tokens if token in keyword_set
        )

        if score > 0:
            scored_sentences.append((score, index, sentence))

    if not scored_sentences:
        return LOW_INFORMATION_SUMMARY

    selected = sorted(scored_sentences, key=lambda item: (-item[0], item[1]))[
        :max_sentences
    ]

    # Preserve source order after ranking so the summary reads naturally.
    selected_in_source_order = sorted(selected, key=lambda item: item[1])
    return " ".join(sentence for _score, _index, sentence in selected_in_source_order)
