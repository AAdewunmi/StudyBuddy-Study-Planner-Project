"""Text processing utilities for deterministic note analysis."""

from __future__ import annotations

import hashlib
import re

TOKEN_PATTERN = re.compile(r"[a-z0-9]+")
SENTENCE_ENDINGS = frozenset(".!?")
UNORDERED_LIST_MARKERS = ("- ", "* ")
ORDERED_LIST_ENDINGS = frozenset(".):")
NON_BOUNDARY_ABBREVIATIONS = frozenset(
    {
        "dr.",
        "e.g.",
        "i.e.",
        "mr.",
        "mrs.",
        "ms.",
        "prof.",
    }
)

STOP_WORDS = frozenset(
    {
        "a",
        "about",
        "above",
        "after",
        "again",
        "against",
        "all",
        "am",
        "an",
        "and",
        "any",
        "are",
        "as",
        "at",
        "be",
        "because",
        "been",
        "before",
        "being",
        "below",
        "between",
        "both",
        "but",
        "by",
        "can",
        "did",
        "do",
        "does",
        "doing",
        "down",
        "during",
        "each",
        "few",
        "for",
        "from",
        "further",
        "had",
        "has",
        "have",
        "having",
        "he",
        "her",
        "here",
        "hers",
        "herself",
        "him",
        "himself",
        "his",
        "how",
        "i",
        "if",
        "in",
        "into",
        "is",
        "it",
        "its",
        "itself",
        "just",
        "me",
        "more",
        "most",
        "my",
        "myself",
        "no",
        "nor",
        "not",
        "of",
        "off",
        "on",
        "once",
        "only",
        "or",
        "other",
        "our",
        "ours",
        "ourselves",
        "out",
        "over",
        "own",
        "same",
        "she",
        "should",
        "so",
        "some",
        "such",
        "than",
        "that",
        "the",
        "their",
        "theirs",
        "them",
        "themselves",
        "then",
        "there",
        "these",
        "they",
        "this",
        "those",
        "through",
        "to",
        "too",
        "under",
        "until",
        "up",
        "very",
        "was",
        "we",
        "were",
        "what",
        "when",
        "where",
        "which",
        "while",
        "who",
        "whom",
        "why",
        "will",
        "with",
        "you",
        "your",
        "yours",
        "yourself",
        "yourselves",
    }
)


def normalise_text(text: str | None) -> str:
    """Return lowercase text with stable whitespace.

    Args:
        text: Raw text supplied by the user.

    Returns:
        A deterministic normalised representation.
    """
    if not text:
        return ""

    return " ".join(text.lower().strip().split())


def tokenize(text: str | None) -> list[str]:
    """Tokenise text into deterministic lowercase alphanumeric tokens.

    Args:
        text: Raw text supplied by the user.

    Returns:
        A list of tokens in source order.
    """
    normalised = normalise_text(text)
    return TOKEN_PATTERN.findall(normalised)


def meaningful_tokens(text: str | None, minimum_length: int = 3) -> list[str]:
    """Return tokens after stop-word and length filtering.

    Args:
        text: Raw text supplied by the user.
        minimum_length: Minimum token length to keep.

    Returns:
        Filtered tokens in source order.
    """
    return [
        token
        for token in tokenize(text)
        if token not in STOP_WORDS and len(token) >= minimum_length
    ]


def _strip_list_marker(line: str) -> str:
    """Return a note line without a simple list marker."""
    stripped = line.strip()

    for marker in UNORDERED_LIST_MARKERS:
        if stripped.startswith(marker):
            return stripped[len(marker) :].strip()

    marker, separator, remainder = stripped.partition(" ")
    if (
        separator
        and remainder.strip()
        and marker[-1:] in ORDERED_LIST_ENDINGS
        and marker[:-1].isdigit()
    ):
        return remainder.strip()

    return stripped


def _source_text_blocks(text: str) -> list[str]:
    """Return paragraph and list-item blocks in source order."""
    blocks: list[str] = []
    current_paragraph: list[str] = []

    def append_current_paragraph() -> None:
        if current_paragraph:
            blocks.append(" ".join(current_paragraph))
            current_paragraph.clear()

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            append_current_paragraph()
            continue

        without_list_marker = _strip_list_marker(line)
        if without_list_marker != line:
            append_current_paragraph()
            if without_list_marker:
                blocks.append(without_list_marker)
            continue

        current_paragraph.append(line)

    append_current_paragraph()
    return blocks


def _is_decimal_point(text: str, index: int) -> bool:
    """Return whether a period is part of a numeric decimal."""
    return (
        text[index] == "."
        and index > 0
        and index + 1 < len(text)
        and text[index - 1].isdigit()
        and text[index + 1].isdigit()
    )


def _ends_with_non_boundary_abbreviation(text: str, index: int) -> bool:
    """Return whether text up to index ends with a known abbreviation."""
    prefix = text[: index + 1].strip().lower()
    return any(
        prefix.endswith(abbreviation)
        for abbreviation in NON_BOUNDARY_ABBREVIATIONS
    )


def _is_sentence_boundary(text: str, index: int) -> bool:
    """Return whether the character at index should end a sentence."""
    if text[index] not in SENTENCE_ENDINGS:
        return False

    if _is_decimal_point(text, index):
        return False

    if _ends_with_non_boundary_abbreviation(text, index):
        return False

    return index + 1 == len(text) or text[index + 1].isspace()


def _split_sentence_block(block: str) -> list[str]:
    """Split one paragraph or list item into sentence-like units."""
    sentences: list[str] = []
    start = 0

    for index in range(len(block)):
        if not _is_sentence_boundary(block, index):
            continue

        sentence = block[start : index + 1].strip()
        if sentence:
            sentences.append(sentence)
        start = index + 1

    remainder = block[start:].strip()
    if remainder:
        sentences.append(remainder)

    return sentences


def split_sentences(text: str | None) -> list[str]:
    """Split text into simple source sentences.

    Args:
        text: Raw text supplied by the user.

    Returns:
        Sentences in source order with surrounding whitespace removed.
    """
    if not text:
        return []

    stripped = text.strip()
    if not stripped:
        return []

    sentences: list[str] = []
    for block in _source_text_blocks(stripped):
        sentences.extend(_split_sentence_block(block))

    return sentences


def source_text_hash(text: str | None) -> str:
    """Return a SHA-256 hash for the normalised source text.

    Args:
        text: Raw text supplied by the user.

    Returns:
        A 64-character SHA-256 hex digest.
    """
    normalised = normalise_text(text)
    return hashlib.sha256(normalised.encode("utf-8")).hexdigest()
