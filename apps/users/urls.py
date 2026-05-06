"""URL routes for StudyBuddy account workflows."""

from __future__ import annotations

from django.contrib.auth.views import LoginView, LogoutView
from django.urls import path

from apps.users import views

app_name = "users"

urlpatterns = [
    path("signup/", views.signup, name="signup"),
    path(
        "login/",
        LoginView.as_view(template_name="users/login.html"),
        name="login",
    ),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("profile/", views.profile, name="profile"),
]
