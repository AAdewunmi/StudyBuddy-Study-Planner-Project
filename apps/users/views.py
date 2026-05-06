"""Views for StudyBuddy account workflows."""

from __future__ import annotations

from django.contrib.auth import login
from django.contrib.auth.decorators import login_required
from django.http import HttpRequest, HttpResponse
from django.shortcuts import redirect, render

from apps.users.forms import UserSignUpForm


def signup(request: HttpRequest) -> HttpResponse:
    """Register a new user and send them to the dashboard."""
    if request.method == "POST":
        form = UserSignUpForm(request.POST)

        if form.is_valid():
            user = form.save()
            login(request, user, backend="django.contrib.auth.backends.ModelBackend")
            return redirect("dashboard:index")
    else:
        form = UserSignUpForm()

    return render(request, "users/signup.html", {"form": form})


@login_required
def profile(request: HttpRequest) -> HttpResponse:
    """Render the authenticated user's profile."""
    return render(request, "users/profile.html")
