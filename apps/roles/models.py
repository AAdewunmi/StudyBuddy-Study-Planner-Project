"""Role models for StudyBuddy access control."""

from __future__ import annotations

from django.conf import settings
from django.db import models


class Role(models.Model):
    """Named role used to support role-aware behaviour in the product."""

    slug = models.SlugField(unique=True)
    display_name = models.CharField(max_length=120, unique=True)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    users = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name="studybuddy_roles",
    )

    class Meta:
        """Model metadata for roles."""

        ordering = ("display_name",)

    def __str__(self) -> str:
        """Return the human-readable role name."""
        return self.display_name
