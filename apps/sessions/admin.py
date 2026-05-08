"""
Django admin registrations for study sessions and notes.
"""

from django.contrib import admin

from apps.sessions.models import StudyNote, StudySession


@admin.register(StudySession)
class StudySessionAdmin(admin.ModelAdmin):
    """
    Admin configuration for inspecting study sessions.
    """

    list_display = (
        "title",
        "subject",
        "owner",
        "status",
        "study_date",
        "duration_minutes",
        "created_at",
    )
    list_filter = (
        "status",
        "subject",
        "study_date",
        "created_at",
    )
    search_fields = (
        "title",
        "subject",
        "owner__email",
    )
    readonly_fields = (
        "created_at",
        "updated_at",
    )


@admin.register(StudyNote)
class StudyNoteAdmin(admin.ModelAdmin):
    """
    Admin configuration for inspecting study notes.
    """

    list_display = (
        "session",
        "session_owner",
        "created_at",
    )
    search_fields = (
        "content",
        "session__title",
        "session__owner__email",
    )
    readonly_fields = ("created_at",)

    def session_owner(self, obj: StudyNote) -> str:
        """
        Return the owner email of the note's parent session.
        """

        return obj.session.owner.email
