"""Text processing utilities for deterministic note analysis."""

from __future__ import annotations

import hashlib
import re

TOKEN_PATTERN = re.compile(r"[a-z0-9]+")
SENTENCE_PATTERN = re.compile(r"(?<=[.!?])\s+")

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

    sentences = SENTENCE_PATTERN.split(stripped)
    return [sentence.strip() for sentence in sentences if sentence.strip()]


def source_text_hash(text: str | None) -> str:
    """Return a SHA-256 hash for the normalised source text.

    Args:
        text: Raw text supplied by the user.

    Returns:
        A 64-character SHA-256 hex digest.
    """
    normalised = normalise_text(text)
    return hashlib.sha256(normalised.encode("utf-8")).hexdigest()