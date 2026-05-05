"""Custom user model for StudyBuddy."""

from __future__ import annotations

from django.contrib.auth.models import AbstractUser, UserManager
from django.db import models
from django.utils.translation import gettext_lazy as _


class CustomUserManager(UserManager):
    """Manager that creates users with email as the login identifier."""

    use_in_migrations = True

    def _create_user(self, email: str, password: str | None, **extra_fields):
        """Create and save a user with the given email and password."""
        if not email:
            raise ValueError("The email address must be set.")

        email = self.normalize_email(email)
        extra_fields.setdefault("username", self._unique_username_from_email(email))

        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)

        return user

    def create_user(self, email: str, password: str | None = None, **extra_fields):
        """Create a regular user."""
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)

        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email: str, password: str | None = None, **extra_fields):
        """Create a superuser for administration tasks."""
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_active", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")

        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self._create_user(email, password, **extra_fields)

    def _unique_username_from_email(self, email: str) -> str:
        """Create a unique username from the email local part."""
        base_username = email.split("@", maxsplit=1)[0][:140] or "user"
        candidate = base_username
        suffix = 1

        while self.model.objects.filter(username__iexact=candidate).exists():
            suffix += 1
            candidate = f"{base_username}-{suffix}"

        return candidate


class CustomUser(AbstractUser):
    """Email-first user model for StudyBuddy accounts."""

    email = models.EmailField(_("email address"), unique=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    objects = CustomUserManager()

    class Meta:
        """Model metadata for custom users."""

        ordering = ("email",)

    def __str__(self) -> str:
        """Return the email address as the user label."""
        return self.email

    @property
    def display_name(self) -> str:
        """Return a friendly name for product screens."""
        full_name = self.get_full_name().strip()
        return full_name or self.email
