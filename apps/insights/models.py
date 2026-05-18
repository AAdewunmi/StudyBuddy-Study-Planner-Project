"""Database models for deterministic study insights."""

from __future__ import annotations

from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.sessions.models import StudySession


class StudyInsight(models.Model):
    """Persisted deterministic NLP output for a user's study session.

    Each insight is generated from the notes attached to a single study
    session. The ``source_hash`` field allows the application to reuse an
    existing insight when the underlying note text has not changed.
    """

    session = models.ForeignKey(
        StudySession,
        on_delete=models.CASCADE,
        related_name="insights",
    )
    summary = models.TextField()
    keywords = models.JSONField(default=list, blank=True)
    confidence = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(0), MaxValueValidator(100)]
    )
    explanation = models.TextField()
    source_hash = models.CharField(max_length=64, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        """Model metadata for insight ordering and uniqueness."""

        ordering = ["-created_at", "-id"]
        constraints = [
            models.UniqueConstraint(
                fields=["session", "source_hash"],
                name="unique_insight_per_session_source",
            )
        ]

    def __str__(self) -> str:
        """Return a readable representation for admin and debugging."""
        return f"Insight for {self.session} ({self.confidence}%)"

    def clean(self) -> None:
        """Validate JSON field shape and source hash format."""
        super().clean()

        if not isinstance(self.keywords, list):
            raise ValidationError({"keywords": "Keywords must be stored as a list."})

        for keyword in self.keywords:
            if not isinstance(keyword, str):
                raise ValidationError(
                    {"keywords": "Each keyword must be stored as a string."}
                )

        if len(self.source_hash) != 64:
            raise ValidationError(
                {"source_hash": "Source hash must be a SHA-256 hex digest."}
            )

    def save(self, *args: object, **kwargs: object) -> None:
        """Validate the insight before saving it."""
        self.full_clean()
        super().save(*args, **kwargs)
