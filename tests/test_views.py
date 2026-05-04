"""View tests for the StudyBuddy Django project."""

from __future__ import annotations

import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse


@pytest.mark.django_db
def test_home_page_renders(client) -> None:
    """The public home page is reachable."""
    response = client.get(reverse("home"))

    assert response.status_code == 200
    assert "StudyBuddy" in response.content.decode()


@pytest.mark.django_db
@pytest.mark.parametrize(
    "url_name",
    [
        "dashboard:index",
        "users:profile",
    ],
)
def test_protected_pages_redirect_anonymous_users(client, url_name: str) -> None:
    """Authenticated pages redirect anonymous users to login."""
    response = client.get(reverse(url_name))

    assert response.status_code == 302
    assert response["Location"].startswith(f"{reverse('users:login')}?next=")


@pytest.mark.django_db
def test_dashboard_renders_for_authenticated_user(client) -> None:
    """Signed-in users can access the dashboard."""
    user = get_user_model().objects.create_user(
        username="linus",
        email="linus@example.com",
        password="password123",
    )
    client.force_login(user)

    response = client.get(reverse("dashboard:index"))

    assert response.status_code == 200
    assert "Dashboard" in response.content.decode()


@pytest.mark.django_db
def test_profile_renders_for_authenticated_user(client) -> None:
    """Signed-in users can access their profile page."""
    user = get_user_model().objects.create_user(
        username="katherine",
        email="katherine@example.com",
        password="password123",
    )
    client.force_login(user)

    response = client.get(reverse("users:profile"))

    assert response.status_code == 200
    assert "Profile" in response.content.decode()


@pytest.mark.django_db
def test_signup_creates_user_and_redirects_to_dashboard(client) -> None:
    """Valid signup creates and authenticates a new user."""
    response = client.post(
        reverse("users:signup"),
        {
            "email": "new@example.com",
            "username": "newuser",
            "password1": "strong-test-password-123",
            "password2": "strong-test-password-123",
        },
    )

    assert response.status_code == 302
    assert response["Location"] == reverse("dashboard:index")
    assert get_user_model().objects.filter(email="new@example.com").exists()
