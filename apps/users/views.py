"""Views for StudyBuddy user accounts."""

from __future__ import annotations

from django.contrib.auth import login
from django.contrib.auth.decorators import login_required
from django.shortcuts import redirect, render

from apps.users.forms import CustomUserCreationForm


def signup(request):
    """Register a new StudyBuddy user."""
    if request.method == "POST":
        form = CustomUserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            login(request, user)
            return redirect("dashboard:index")
    else:
        form = CustomUserCreationForm()

    return render(request, "registration/signup.html", {"form": form})


@login_required
def profile(request):
    """Render the signed-in user's profile page."""
    return render(request, "users/profile.html")
