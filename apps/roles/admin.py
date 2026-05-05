"""Admin configuration for role management."""

from __future__ import annotations

from django.contrib import admin

from apps.roles.models import Role


@admin.register(Role)
class RoleAdmin(admin.ModelAdmin):
    """Admin interface for StudyBuddy roles."""

    list_display = ("display_name", "slug", "created_at", "updated_at")
    search_fields = ("display_name", "slug", "description")
    prepopulated_fields = {"slug": ("display_name",)}
    readonly_fields = ("created_at", "updated_at")