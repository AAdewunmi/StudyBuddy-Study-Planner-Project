"""Django admin registration for study insights."""

from __future__ import annotations

from django.contrib import admin

from apps.insights.models import StudyInsight


@admin.register(StudyInsight)
class StudyInsightAdmin(admin.ModelAdmin):
    """Admin configuration for generated study insights."""

    list_display = (
        "id",
        "owner",
        "session",
        "confidence",
        "keywords_preview",
        "created_at",
    )
    list_filter = ("confidence", "created_at")
    search_fields = (
        "owner__email",
        "session__title",
        "summary",
        "keywords",
        "source_hash",
    )
    readonly_fields = ("created_at", "updated_at", "source_hash")
    ordering = ("-created_at", "-id")

    @admin.display(description="Keywords")
    def keywords_preview(self, obj: StudyInsight) -> str:
        """Return a compact keyword preview for the admin list view."""
        return ", ".join(obj.keywords[:5])