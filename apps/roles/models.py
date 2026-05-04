"""Role models for StudyBuddy users."""

from __future__ import annotations

from django.conf import settings
from django.db import models


class Role(models.Model):
    """Named role that can be assigned to users."""

    name = models.CharField(max_length=80, unique=True)
    slug = models.SlugField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    users = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name="studybuddy_roles",
    )

    class Meta:
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name
