"""URL routes for study sessions."""

from __future__ import annotations

from django.urls import path

from apps.sessions.views import (
    StudyNoteCreateView,
    StudyNoteDeleteView,
    StudyNoteUpdateView,
    StudySessionCreateView,
    StudySessionDetailView,
    StudySessionListView,
    StudySessionUpdateView,
)

app_name = "sessions"

urlpatterns = [
    path("", StudySessionListView.as_view(), name="list"),
    path("new/", StudySessionCreateView.as_view(), name="create"),
    path("<int:pk>/", StudySessionDetailView.as_view(), name="detail"),
    path("<int:pk>/edit/", StudySessionUpdateView.as_view(), name="update"),
    path("<int:pk>/notes/new/", StudyNoteCreateView.as_view(), name="add_note"),
    path(
        "<int:pk>/notes/<int:note_pk>/edit/",
        StudyNoteUpdateView.as_view(),
        name="update_note",
    ),
    path(
        "<int:pk>/notes/<int:note_pk>/delete/",
        StudyNoteDeleteView.as_view(),
        name="delete_note",
    ),
]
