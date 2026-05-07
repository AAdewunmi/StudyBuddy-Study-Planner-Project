"""Integration tests for user authentication views."""

from __future__ import annotations

import pytest
from django.contrib.auth import get_user_model
from django.urls import reverse

from apps.roles.factories import RoleFactory
from apps.users.factories import CustomUserFactory
from apps.users.forms import UserSignUpForm

CustomUser = get_user_model()


@pytest.mark.django_db
def test_signup_page_renders(client):
    """The signup page renders a registration form."""
    response = client.get(reverse("users:signup"))

    assert response.status_code == 200
    assert b"Create your StudyBuddy account" in response.content
    assert b"Create Account" in response.content
    assert b"New Account" in response.content


@pytest.mark.django_db
def test_authenticated_signup_redirects_to_dashboard(client):
    """Signed-in users do not need the public signup page."""
    user = CustomUserFactory(email="signed-in@example.com")
    client.force_login(user)

    response = client.get(reverse("users:signup"))

    assert response.status_code == 302
    assert response["Location"] == reverse("dashboard:index")


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
def test_signup_follows_redirect_and_keeps_user_authenticated(client):
    """A signup request reaches the dashboard and keeps the user signed in."""
    response = client.post(
        reverse("users:signup"),
        {
            "email": "journey.signup@example.com",
            "username": "",
            "first_name": "Journey",
            "last_name": "Signup",
            "password1": "StrongPassword123!",
            "password2": "StrongPassword123!",
        },
        follow=True,
    )

    assert response.status_code == 200
    assert response.redirect_chain == [(reverse("dashboard:index"), 302)]
    assert b"Dashboard" in response.content

    dashboard_response = client.get(reverse("dashboard:index"))
    profile_response = client.get(reverse("users:profile"))

    assert dashboard_response.status_code == 200
    assert profile_response.status_code == 200
    assert b"journey.signup@example.com" in profile_response.content


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
def test_signup_rejects_duplicate_username(client):
    """Signup rejects explicitly supplied usernames already in use."""
    CustomUserFactory(username="existing-user")

    response = client.post(
        reverse("users:signup"),
        {
            "email": "unique@example.com",
            "username": "existing-user",
            "first_name": "Unique",
            "last_name": "User",
            "password1": "StrongPassword123!",
            "password2": "StrongPassword123!",
        },
    )

    assert response.status_code == 200
    assert b"A user with this username already exists." in response.content


@pytest.mark.django_db
def test_signup_generates_unique_username_when_email_local_part_exists(client):
    """Blank usernames are derived from email and made unique."""
    CustomUserFactory(email="learner@example.com", username="learner")

    response = client.post(
        reverse("users:signup"),
        {
            "email": "learner@studybuddy.test",
            "username": "",
            "first_name": "New",
            "last_name": "Learner",
            "password1": "StrongPassword123!",
            "password2": "StrongPassword123!",
        },
    )

    assert response.status_code == 302
    user = CustomUser.objects.get(email="learner@studybuddy.test")

    assert user.username == "learner-2"


@pytest.mark.django_db
def test_signup_form_save_commit_false_builds_unsaved_user():
    """Signup form can build a valid custom user without persisting it."""
    form = UserSignUpForm(
        data={
            "email": "draft@example.com",
            "username": "",
            "first_name": "Draft",
            "last_name": "User",
            "password1": "StrongPassword123!",
            "password2": "StrongPassword123!",
        }
    )

    assert form.is_valid()

    user = form.save(commit=False)

    assert user.pk is None
    assert user.email == "draft@example.com"
    assert user.username == "draft"
    assert user.check_password("StrongPassword123!")
    assert not CustomUser.objects.filter(email="draft@example.com").exists()


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
def test_login_follows_redirect_and_keeps_user_authenticated(client):
    """A login request reaches the dashboard and unlocks protected pages."""
    user = CustomUserFactory(email="journey.login@example.com")

    response = client.post(
        reverse("users:login"),
        {
            "username": user.email,
            "password": "password123",
        },
        follow=True,
    )

    assert response.status_code == 200
    assert response.redirect_chain == [(reverse("dashboard:index"), 302)]
    assert b"Dashboard" in response.content

    dashboard_response = client.get(reverse("dashboard:index"))
    profile_response = client.get(reverse("users:profile"))

    assert dashboard_response.status_code == 200
    assert profile_response.status_code == 200
    assert b"journey.login@example.com" in profile_response.content


@pytest.mark.django_db
def test_authenticated_login_redirects_to_dashboard(client):
    """Signed-in users are sent to the post-login product surface."""
    user = CustomUserFactory(email="already@example.com")
    client.force_login(user)

    response = client.get(reverse("users:login"))

    assert response.status_code == 302
    assert response["Location"] == reverse("dashboard:index")


@pytest.mark.django_db
def test_logout_redirects_to_home(client):
    """Logout returns users to the public landing page."""
    user = CustomUserFactory(email="logout@example.com")
    client.force_login(user)

    response = client.post(reverse("users:logout"))

    assert response.status_code == 302
    assert response["Location"] == reverse("home")


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


@pytest.mark.django_db
def test_authenticated_profile_receives_roles_from_view_context(client):
    """Profile role display is fed by view context, not template permissions."""
    user = CustomUserFactory(email="role.profile@example.com")
    role = RoleFactory(slug="learner", display_name="Learner")
    user.studybuddy_roles.add(role)
    client.force_login(user)

    response = client.get(reverse("users:profile"))

    assert response.status_code == 200
    assert list(response.context["roles"]) == [role]
    assert b"Learner" in response.content
