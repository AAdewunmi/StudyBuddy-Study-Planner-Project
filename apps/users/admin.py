"""Admin configuration for the custom StudyBuddy user model."""

from __future__ import annotations

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.translation import gettext_lazy as _

from apps.roles.models import Role
from apps.users.models import CustomUser


class RoleMembershipInline(admin.TabularInline):
    """Inline role assignments for StudyBuddy users."""

    model = Role.users.through
    extra = 0
    verbose_name = "role assignment"
    verbose_name_plural = "role assignments"


@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    """Admin interface for email-first StudyBuddy users."""

    list_display = ("email", "username", "first_name", "last_name", "is_staff")
    list_filter = ("is_staff", "is_superuser", "is_active", "groups")
    search_fields = ("email", "username", "first_name", "last_name")
    ordering = ("email",)
    filter_horizontal = ("groups", "user_permissions")
    inlines = (RoleMembershipInline,)

    fieldsets = (
        (None, {"fields": ("email", "password")}),
        (_("Personal info"), {"fields": ("username", "first_name", "last_name")}),
        (
            _("Permissions"),
            {
                "fields": (
                    "is_active",
                    "is_staff",
                    "is_superuser",
                    "groups",
                    "user_permissions",
                ),
            },
        ),
        (_("Important dates"), {"fields": ("last_login", "date_joined")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "password1", "password2"),
            },
        ),
    )
