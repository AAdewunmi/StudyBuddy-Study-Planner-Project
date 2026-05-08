"""
Database models for the StudyBuddy session workflow.

The sessions app owns the core study activity domain for Sprint 2:
study sessions and notes attached to those sessions.
"""

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone


class StudySession(models.Model):
    """
    A user-owned study session.

    A session records the subject, title, lifecycle status, study date, and
    duration for a single piece of study activity. It is scoped to one owner
    so user data can be filtered safely at query level.
    """

    class Status(models.TextChoices):
        """
        Allowed lifecycle states for a study session.
        """

        PLANNED = "planned", "Planned"
        IN_PROGRESS = "in_progress", "In progress"
        COMPLETED = "completed", "Completed"

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="study_sessions",
    )
    title = models.CharField(max_length=160)
    subject = models.CharField(max_length=120)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PLANNED,
    )
    study_date = models.DateField(default=timezone.localdate)
    duration_minutes = models.PositiveIntegerField(
        validators=[
            MinValueValidator(1),
            MaxValueValidator(1440),
        ],
        help_text="Duration must be between 1 minute and 24 hours.",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        """
        Model metadata for stable user-facing ordering.
        """

        ordering = ["-study_date", "-created_at"]

    def __str__(self) -> str:
        """
        Return a readable label for admin, shell, and debugging output.
        """

        return f"{self.title} ({self.subject})"

    def clean(self) -> None:
        """
        Validate domain rules that depend on multiple fields.
        """

        super().clean()

        if (
            self.status == self.Status.COMPLETED
            and self.study_date
            and self.study_date > timezone.localdate()
        ):
            raise ValidationError(
                {
                    "study_date": "Completed study sessions cannot be dated in the future.",
                }
            )

    @property
    def note_count(self) -> int:
        """
        Return the number of notes attached to this session.
        """

        if not self.pk:
            return 0

        return self.notes.count()


class StudyNote(models.Model):
    """
    A user-authored note attached to a study session.

    Ownership is inherited through the parent StudySession. Views must resolve
    the session through the current user before creating or displaying notes.
    """

    session = models.ForeignKey(
        StudySession,
        on_delete=models.CASCADE,
        related_name="notes",
    )
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        """
        Model metadata for displaying the newest notes first.
        """

        ordering = ["-created_at"]

    def __str__(self) -> str:
        """
        Return a readable note label for admin and shell output.
        """

        return f"Note for {self.session.title}"

    def clean(self) -> None:
        """
        Validate that notes contain enough information to be useful.
        """

        super().clean()

        if len(self.content.strip()) < 10:
            raise ValidationError(
                {
                    "content": "Study notes must contain at least 10 characters.",
                }
            )

    @property
    def word_count(self) -> int:
        """
        Return the number of whitespace-separated words in the note.
        """

        return len(self.content.split())