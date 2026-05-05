"""Model tests for StudyBuddy roles."""

from __future__ import annotations

import pytest
from django.db import IntegrityError, transaction

from apps.roles.factories import RoleFactory
from apps.roles.models import Role


@pytest.mark.django_db
def test_role_string_uses_display_name():
    """The role string representation uses the product-facing display name."""
    role = RoleFactory(display_name="Learner")

    assert str(role) == "Learner"


@pytest.mark.django_db
def test_role_slug_must_be_unique():
    """Duplicate role slugs are rejected by the database."""
    RoleFactory(slug="learner", display_name="Learner")

    with pytest.raises(IntegrityError):
        with transaction.atomic():
            Role.objects.create(slug="learner", display_name="Learner Duplicate")
