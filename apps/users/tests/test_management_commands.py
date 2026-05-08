"""Tests for user management commands."""

from __future__ import annotations

from io import StringIO

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command

from apps.roles.models import Role
from apps.users.management.commands.create_studybuddy_user import SAMPLE_USERS

pytestmark = pytest.mark.django_db


def test_create_studybuddy_user_creates_sample_users() -> None:
    """The command creates the complete sample user set with product roles."""
    output = StringIO()

    call_command("create_studybuddy_user", stdout=output)

    User = get_user_model()

    assert (
        User.objects.filter(email__in=[user.email for user in SAMPLE_USERS]).count()
        == 10
    )
    assert User.objects.filter(studybuddy_roles__slug="student").count() == 6
    assert User.objects.filter(studybuddy_roles__slug="tutor").count() == 3
    assert User.objects.filter(studybuddy_roles__slug="admin").count() == 1

    admin = User.objects.get(email="admin@example.com")

    assert admin.is_staff
    assert admin.is_superuser
    assert admin.studybuddy_roles.filter(slug="admin").exists()

    student = User.objects.get(email="student1@example.com")

    assert student.check_password("StrongPassword123!")
    assert not student.is_staff
    assert not student.is_superuser
    assert student.studybuddy_roles.filter(slug="student").exists()

    command_output = output.getvalue()

    assert "Creating StudyBuddy sample users..." in command_output
    assert "student1@example.com | student" in command_output
    assert "tutor1@example.com | tutor" in command_output
    assert "admin@example.com | admin" in command_output
    assert "StudyBuddy sample users ready: 10 created, 0 updated, 10 total." in (
        command_output
    )


def test_create_studybuddy_user_is_idempotent() -> None:
    """Running the command repeatedly updates existing samples without duplicates."""
    output = StringIO()

    call_command("create_studybuddy_user", stdout=StringIO())
    call_command("create_studybuddy_user", password="NewPassword123!", stdout=output)

    User = get_user_model()

    assert (
        User.objects.filter(email__in=[user.email for user in SAMPLE_USERS]).count()
        == 10
    )
    assert User.objects.get(email="student1@example.com").check_password(
        "NewPassword123!"
    )
    assert "StudyBuddy sample users ready: 0 created, 10 updated, 10 total." in (
        output.getvalue()
    )


def test_create_studybuddy_user_ensures_roles_exist() -> None:
    """The command creates the supported product roles when missing."""
    call_command("create_studybuddy_user", stdout=StringIO())

    assert set(Role.objects.values_list("slug", flat=True)) >= {
        "student",
        "tutor",
        "admin",
    }
