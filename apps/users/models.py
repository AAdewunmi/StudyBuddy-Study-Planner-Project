"""Custom user model for StudyBuddy."""

from __future__ import annotations

from django.contrib.auth.models import AbstractUser
from django.db import models


class CustomUser(AbstractUser):
    """StudyBuddy user with email treated as a first-class identifier."""

    email = models.EmailField(unique=True)

    def __str__(self) -> str:
        return self.email or self.username
