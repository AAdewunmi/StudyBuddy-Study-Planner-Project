"""Test factories for user data."""

from __future__ import annotations

import factory
from django.contrib.auth import get_user_model

from apps.roles.factories import RoleFactory

CustomUser = get_user_model()


class CustomUserFactory(factory.django.DjangoModelFactory):
    """Create realistic custom users for tests."""

    class Meta:
        model = CustomUser
        django_get_or_create = ("email",)

    email = factory.Sequence(lambda number: f"user{number}@example.com")
    username = factory.Sequence(lambda number: f"user{number}")
    first_name = "Study"
    last_name = "Buddy"
    password = factory.django.Password("password123")


class UserWithRoleFactory(CustomUserFactory):
    """Create a user and attach a role after persistence."""

    @factory.post_generation
    def role(self, create: bool, extracted, **kwargs) -> None:
        """Attach an explicit role or create a default test role."""
        if not create:
            return

        role = extracted or RoleFactory(slug="learner", display_name="Learner")
        self.studybuddy_roles.add(role)
