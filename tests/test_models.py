"""Model tests for StudyBuddy apps."""

from __future__ import annotations

import pytest
from django.contrib.auth import get_user_model

from apps.roles.models import Role


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
def test_custom_user_manager_requires_email() -> None:
    """Users cannot be created without an email address."""
    with pytest.raises(ValueError, match="email address must be set"):
        get_user_model().objects.create_user(email="", password="password123")


@pytest.mark.django_db
def test_custom_user_manager_generates_unique_usernames() -> None:
    """Email-first user creation fills usernames when none are provided."""
    User = get_user_model()

    first_user = User.objects.create_user(
        email="learner@example.com",
        password="password123",
    )
    second_user = User.objects.create_user(
        email="LEARNER@school.example",
        password="password123",
    )

    assert first_user.email == "learner@example.com"
    assert first_user.username == "learner"
    assert second_user.email == "LEARNER@school.example"
    assert second_user.username == "LEARNER-2"


@pytest.mark.django_db
def test_custom_user_manager_creates_superuser() -> None:
    """Superuser creation applies the required admin flags."""
    user = get_user_model().objects.create_superuser(
        email="admin@example.com",
        password="password123",
    )

    assert user.is_staff is True
    assert user.is_superuser is True
    assert user.is_active is True


@pytest.mark.django_db
@pytest.mark.parametrize(
    ("extra_fields", "message"),
    [
        ({"is_staff": False}, "Superuser must have is_staff=True."),
        ({"is_superuser": False}, "Superuser must have is_superuser=True."),
    ],
)
def test_custom_user_manager_rejects_invalid_superuser_flags(
    extra_fields: dict[str, bool],
    message: str,
) -> None:
    """Superuser creation rejects inconsistent permission flags."""
    with pytest.raises(ValueError, match=message):
        get_user_model().objects.create_superuser(
            email="admin@example.com",
            password="password123",
            **extra_fields,
        )


@pytest.mark.django_db
def test_custom_user_display_name_prefers_full_name() -> None:
    """Display names use full names before falling back to email."""
    user = get_user_model().objects.create_user(
        email="grace@example.com",
        password="password123",
        first_name="Grace",
        last_name="Hopper",
    )

    assert user.display_name == "Grace Hopper"


@pytest.mark.django_db
def test_custom_user_display_name_falls_back_to_email() -> None:
    """Display names fall back to email when no name is set."""
    user = get_user_model().objects.create_user(
        email="alan@example.com",
        password="password123",
    )

    assert user.display_name == "alan@example.com"


@pytest.mark.django_db
def test_role_string_uses_name() -> None:
    """Roles display with their human-readable name."""
    role = Role.objects.create(display_name="Student", slug="student")

    assert str(role) == "Student"


@pytest.mark.django_db
def test_role_can_be_assigned_to_user() -> None:
    """Roles can be linked to the custom user model."""
    user = get_user_model().objects.create_user(
        username="grace",
        email="grace@example.com",
        password="password123",
    )
    role = Role.objects.create(display_name="Tutor", slug="tutor")

    role.users.add(user)

    assert user.studybuddy_roles.get() == role
