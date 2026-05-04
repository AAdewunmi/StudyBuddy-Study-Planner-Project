"""Forms for StudyBuddy user accounts."""

from __future__ import annotations

from django.contrib.auth.forms import UserCreationForm

from apps.users.models import CustomUser


class CustomUserCreationForm(UserCreationForm):
    """Signup form for the custom user model."""

    class Meta(UserCreationForm.Meta):
        model = CustomUser
        fields = ("email", "username")
