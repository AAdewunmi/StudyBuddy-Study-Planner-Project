"""Model tests for the custom user model."""

from __future__ import annotations

import pytest
from django.contrib.auth import get_user_model

from apps.roles.factories import RoleFactory
from apps.users.factories import CustomUserFactory

CustomUser = get_user_model()


@pytest.mark.django_db
def test_user_uses_email_as_login_identifier():
    """Custom users use email as their natural login identifier."""
    user = CustomUser.objects.create_user(
        email="learner@EXAMPLE.COM",
        password="StrongPassword123!",
    )

    assert CustomUser.USERNAME_FIELD == "email"
    assert user.email == "learner@example.com"
    assert user.username == "learner"
    assert user.check_password("StrongPassword123!")


@pytest.mark.django_db
def test_user_can_be_assigned_roles():
    """Users can be connected to role records for access control."""
    role = RoleFactory(slug="learner", display_name="Learner")
    user = CustomUserFactory()

    user.studybuddy_roles.add(role)

    assert user.studybuddy_roles.filter(slug="learner").exists()
