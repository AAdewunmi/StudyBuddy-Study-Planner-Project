"""Root URL configuration for StudyBuddy."""

from __future__ import annotations

from django.contrib import admin
from django.urls import include, path
from django.views.generic import TemplateView

urlpatterns = [
    path("", TemplateView.as_view(template_name="home.html"), name="home"),
    path("admin/", admin.site.urls),
    path("accounts/", include("apps.users.urls")),
    path("dashboard/", include("apps.dashboard.urls")),
]
