"""URL routes for StudyBuddy study session workflows."""

from __future__ import annotations

from django.urls import path

from apps.sessions import views

app_name = "sessions"

urlpatterns = [
    path("", views.session_list, name="list"),
    path("new/", views.session_create, name="create"),
    path("<int:pk>/", views.session_detail, name="detail"),
    path("<int:pk>/edit/", views.session_update, name="update"),
    path("<int:pk>/notes/new/", views.session_add_note, name="add_note"),
    path(
        "<int:pk>/notes/<int:note_pk>/edit/",
        views.session_update_note,
        name="update_note",
    ),
    path(
        "<int:pk>/notes/<int:note_pk>/delete/",
        views.session_delete_note,
        name="delete_note",
    ),
]
