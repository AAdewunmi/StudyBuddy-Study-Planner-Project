"""User account URL routes."""

from __future__ import annotations

from django.contrib.auth import views as auth_views
from django.urls import path

from apps.users import views

app_name = "users"

urlpatterns = [
    path("login/", auth_views.LoginView.as_view(), name="login"),
    path("logout/", auth_views.LogoutView.as_view(), name="logout"),
    path("profile/", views.profile, name="profile"),
    path("signup/", views.signup, name="signup"),
]
