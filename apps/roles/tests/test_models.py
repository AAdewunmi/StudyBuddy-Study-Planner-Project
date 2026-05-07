"""Model tests for StudyBuddy roles."""

from __future__ import annotations

import pytest
from django.contrib.auth.models import AnonymousUser
from django.db import IntegrityError, transaction

from apps.roles.factories import RoleFactory
from apps.roles.models import Role
from apps.roles.permissions import user_has_any_role, user_has_role
from apps.users.factories import CustomUserFactory


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


@pytest.mark.django_db
@pytest.mark.parametrize(
    ("trait", "slug", "display_name"),
    [
        ("student", "student", "Student"),
        ("tutor", "tutor", "Tutor"),
        ("admin", "admin", "Admin"),
    ],
)
def test_role_factory_common_role_traits(trait, slug, display_name):
    """Common role traits provide stable slugs for access-control tests."""
    role = RoleFactory(**{trait: True})

    assert role.slug == slug
    assert role.display_name == display_name


@pytest.mark.django_db
def test_user_has_role_uses_studybuddy_roles_relation():
    """Role helpers use the current user-side StudyBuddy role relation."""
    user = CustomUserFactory()
    role = RoleFactory(slug="learner", display_name="Learner")
    user.studybuddy_roles.add(role)

    assert user_has_role(user, "learner")
    assert user_has_any_role(user, ["admin", "learner"])
    assert not user_has_role(user, "admin")


@pytest.mark.django_db
def test_role_helpers_handle_anonymous_users_and_superusers():
    """Anonymous users fail role checks while superusers pass them."""
    superuser = CustomUserFactory(is_staff=True, is_superuser=True)

    assert not user_has_role(AnonymousUser(), "admin")
    assert user_has_role(superuser, "admin")
