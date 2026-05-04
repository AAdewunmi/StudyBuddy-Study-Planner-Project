"""Model tests for StudyBuddy apps."""

from __future__ import annotations

import pytest
from apps.roles.models import Role
from django.contrib.auth import get_user_model


@pytest.mark.django_db
def test_custom_user_string_uses_email() -> None:
    """Custom users display with their email address when available."""
    user = get_user_model().objects.create_user(
        username="ada",
        email="ada@example.com",
        password="password123",
    )

    assert str(user) == "ada@example.com"


@pytest.mark.django_db
def test_role_string_uses_name() -> None:
    """Roles display with their human-readable name."""
    role = Role.objects.create(name="Student", slug="student")

    assert str(role) == "Student"


@pytest.mark.django_db
def test_role_can_be_assigned_to_user() -> None:
    """Roles can be linked to the custom user model."""
    user = get_user_model().objects.create_user(
        username="grace",
        email="grace@example.com",
        password="password123",
    )
    role = Role.objects.create(name="Tutor", slug="tutor")

    role.users.add(user)

    assert user.studybuddy_roles.get() == role
