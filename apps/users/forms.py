"""Forms for StudyBuddy user registration and account workflows."""

from __future__ import annotations

from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.forms import UserCreationForm

CustomUser = get_user_model()


class UserSignUpForm(UserCreationForm):
    """Form used by visitors to create a StudyBuddy account."""

    email = forms.EmailField(
        label="Email address",
        help_text="Use this email address when signing in.",
    )
    username = forms.CharField(
        required=False,
        help_text="Optional. If left blank, StudyBuddy derives one from your email.",
    )

    class Meta:
        """Form metadata for user signup."""

        model = CustomUser
        fields = ("email", "username", "first_name", "last_name", "password1", "password2")

    def clean_email(self) -> str:
        """Validate that the submitted email is unique."""
        email = self.cleaned_data["email"].strip().lower()

        if CustomUser.objects.filter(email__iexact=email).exists():
            raise forms.ValidationError("A user with this email already exists.")

        return email

    def clean_username(self) -> str:
        """Validate an optional username only when the user supplies one."""
        username = self.cleaned_data.get("username", "").strip()

        if username and CustomUser.objects.filter(username__iexact=username).exists():
            raise forms.ValidationError("A user with this username already exists.")

        return username

    def save(self, commit: bool = True):
        """Create a user with a safe username and email-first login."""
        user = super().save(commit=False)
        user.email = self.cleaned_data["email"]
        user.username = self.cleaned_data.get("username") or self._unique_username()

        if commit:
            user.save()
            self.save_m2m()

        return user

    def _unique_username(self) -> str:
        """Build a unique username from the email local part."""
        email = self.cleaned_data["email"]
        base_username = email.split("@", maxsplit=1)[0][:140] or "user"
        candidate = base_username
        suffix = 1

        while CustomUser.objects.filter(username__iexact=candidate).exists():
            suffix += 1
            candidate = f"{base_username}-{suffix}"

        return candidate
