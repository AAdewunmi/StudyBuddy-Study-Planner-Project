"""URL routes for study insights."""

from __future__ import annotations

from django.urls import path

from apps.insights.views import GenerateInsightView, InsightListView

app_name = "insights"

urlpatterns = [
    path("", InsightListView.as_view(), name="list"),
    path(
        "sessions/<int:session_id>/generate/",
        GenerateInsightView.as_view(),
        name="generate",
    ),
]
