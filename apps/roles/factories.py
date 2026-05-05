"""Test factories for role data."""

from __future__ import annotations

import factory

from apps.roles.models import Role


class RoleFactory(factory.django.DjangoModelFactory):
    """Create realistic role records for tests."""

    class Meta:
        model = Role
        django_get_or_create = ("slug",)

    class Params:
        student = factory.Trait(
            slug="student",
            display_name="Student",
            description="Student role used by automated tests.",
        )
        tutor = factory.Trait(
            slug="tutor",
            display_name="Tutor",
            description="Tutor role used by automated tests.",
        )
        admin = factory.Trait(
            slug="admin",
            display_name="Admin",
            description="Admin role used by automated tests.",
        )

    slug = factory.Sequence(lambda number: f"role-{number}")
    display_name = factory.Sequence(lambda number: f"Role {number}")
    description = "Role used by automated tests."
