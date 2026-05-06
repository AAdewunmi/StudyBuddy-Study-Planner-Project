"""Integration tests for user authentication views."""

from __future__ import annotations

import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse

from apps.users.factories import CustomUserFactory

CustomUser = get_user_model()


@pytest.mark.django_db
def test_signup_page_renders(client):
    """The signup page renders a registration form."""
    response = client.get(reverse("users:signup"))

    assert response.status_code == 200
    assert b"Create Account" in response.content
    assert b"New Account" in response.content


@pytest.mark.django_db
def test_signup_creates_user_and_redirects_to_dashboard(client):
    """A valid signup creates a user and sends them to the dashboard."""
    response = client.post(
        reverse("users:signup"),
        {
            "email": "new.user@example.com",
            "username": "",
            "first_name": "New",
            "last_name": "User",
            "password1": "StrongPassword123!",
            "password2": "StrongPassword123!",
        },
    )

    assert response.status_code == 302
    assert response["Location"] == reverse("dashboard:index")
    assert CustomUser.objects.filter(email="new.user@example.com").exists()


@pytest.mark.django_db
def test_signup_rejects_duplicate_email(client):
    """Signup rejects email addresses that already belong to another user."""
    CustomUserFactory(email="duplicate@example.com")

    response = client.post(
        reverse("users:signup"),
        {
            "email": "duplicate@example.com",
            "username": "duplicate-user",
            "first_name": "Duplicate",
            "last_name": "User",
            "password1": "StrongPassword123!",
            "password2": "StrongPassword123!",
        },
    )

    assert response.status_code == 200
    assert b"A user with this email already exists." in response.content


@pytest.mark.django_db
def test_login_with_email_redirects_to_dashboard(client):
    """Users can log in with their email address and password."""
    user = CustomUserFactory(email="login@example.com")

    response = client.post(
        reverse("users:login"),
        {
            "username": user.email,
            "password": "password123",
        },
    )

    assert response.status_code == 302
    assert response["Location"] == reverse("dashboard:index")


@pytest.mark.django_db
def test_profile_requires_login(client):
    """Anonymous users are redirected before viewing a profile."""
    response = client.get(reverse("users:profile"))

    assert response.status_code == 302
    assert response["Location"].startswith(f"{reverse('users:login')}?next=")


@pytest.mark.django_db
def test_authenticated_profile_shows_user_email(client):
    """Authenticated users can view their account profile."""
    user = CustomUserFactory(email="profile@example.com")
    client.force_login(user)

    response = client.get(reverse("users:profile"))

    assert response.status_code == 200
    assert b"profile@example.com" in response.content
