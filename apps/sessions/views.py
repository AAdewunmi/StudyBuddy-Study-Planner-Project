"""Views for the StudyBuddy study session workflow."""

from __future__ import annotations

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.http import HttpRequest, HttpResponse
from django.shortcuts import redirect, render
from django.views.decorators.http import require_POST

from apps.sessions.forms import StudyNoteForm, StudySessionForm
from apps.sessions.selectors import (
    get_notes_for_session,
    get_session_for_user_or_404,
    get_sessions_for_user,
)


@login_required
def session_list(request: HttpRequest) -> HttpResponse:
    """Render the authenticated user's study sessions."""
    sessions = get_sessions_for_user(request.user)

    return render(
        request,
        "sessions/session_list.html",
        {
            "sessions": sessions,
        },
    )


@login_required
def session_create(request: HttpRequest) -> HttpResponse:
    """Create a study session owned by the current user."""
    if request.method == "POST":
        form = StudySessionForm(request.POST)

        if form.is_valid():
            session = form.save(commit=False)
            session.owner = request.user
            session.save()
            messages.success(request, "Study session created.")
            return redirect("sessions:detail", pk=session.pk)
    else:
        form = StudySessionForm()

    return render(
        request,
        "sessions/session_form.html",
        {
            "form": form,
            "page_title": "Create study session",
            "submit_label": "Create session",
        },
    )


@login_required
def session_detail(request: HttpRequest, pk: int) -> HttpResponse:
    """Render a user-owned study session and its notes."""
    session = get_session_for_user_or_404(request.user, pk)
    note_form = StudyNoteForm()

    return render(
        request,
        "sessions/session_detail.html",
        {
            "session": session,
            "notes": get_notes_for_session(session),
            "note_form": note_form,
        },
    )


@login_required
def session_update(request: HttpRequest, pk: int) -> HttpResponse:
    """Update a study session owned by the current user."""
    session = get_session_for_user_or_404(request.user, pk)

    if request.method == "POST":
        form = StudySessionForm(request.POST, instance=session)

        if form.is_valid():
            form.save()
            messages.success(request, "Study session updated.")
            return redirect("sessions:detail", pk=session.pk)
    else:
        form = StudySessionForm(instance=session)

    return render(
        request,
        "sessions/session_form.html",
        {
            "form": form,
            "session": session,
            "page_title": "Edit study session",
            "submit_label": "Save changes",
        },
    )


@login_required
@require_POST
def session_add_note(request: HttpRequest, pk: int) -> HttpResponse:
    """Add a note to a user-owned study session."""
    session = get_session_for_user_or_404(request.user, pk)
    form = StudyNoteForm(request.POST)

    if form.is_valid():
        note = form.save(commit=False)
        note.session = session
        note.save()
        messages.success(request, "Study note added.")
        return redirect("sessions:detail", pk=session.pk)

    return render(
        request,
        "sessions/session_detail.html",
        {
            "session": session,
            "notes": get_notes_for_session(session),
            "note_form": form,
        },
        status=400,
    )
