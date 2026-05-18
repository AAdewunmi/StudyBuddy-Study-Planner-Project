"""Views for the StudyBuddy session workflow."""

from __future__ import annotations

from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.shortcuts import redirect, render
from django.urls import reverse
from django.views import View
from django.views.generic import CreateView, DetailView, ListView, UpdateView

from apps.insights.selectors import get_latest_session_insight
from apps.sessions.forms import StudyNoteForm, StudySessionForm
from apps.sessions.models import StudySession
from apps.sessions.selectors import (
    get_note_for_user_or_404,
    get_notes_for_session,
    get_session_for_user_or_404,
    get_sessions_for_user,
)


def session_detail_context(
    *,
    study_session: StudySession,
    user: object,
    note_form: StudyNoteForm | None = None,
    edit_note_form: StudyNoteForm | None = None,
    editing_note: object | None = None,
) -> dict[str, object]:
    """Build shared context for the session detail page."""
    context = {
        "session": study_session,
        "study_session": study_session,
        "note_form": note_form or StudyNoteForm(),
        "notes": get_notes_for_session(study_session),
        "latest_insight": get_latest_session_insight(
            session=study_session,
            user=user,
        ),
    }

    if edit_note_form is not None:
        context["edit_note_form"] = edit_note_form

    if editing_note is not None:
        context["editing_note"] = editing_note

    return context


class StudySessionListView(LoginRequiredMixin, ListView):
    """Display study sessions owned by the authenticated user."""

    model = StudySession
    template_name = "sessions/session_list.html"
    context_object_name = "sessions"

    def get_queryset(self):
        """Return sessions scoped to the authenticated user."""
        return get_sessions_for_user(self.request.user)

    def get_context_data(self, **kwargs):
        """Expose both legacy and explicit context names."""
        context = super().get_context_data(**kwargs)
        context["study_sessions"] = context["sessions"]
        return context


class StudySessionCreateView(LoginRequiredMixin, CreateView):
    """Create a study session for the authenticated user."""

    model = StudySession
    form_class = StudySessionForm
    template_name = "sessions/session_form.html"

    def form_valid(self, form):
        """Attach the current user as owner before saving."""
        form.instance.owner = self.request.user
        messages.success(self.request, "Study session created successfully.")
        return super().form_valid(form)

    def get_context_data(self, **kwargs):
        """Add create-page labels to the form context."""
        context = super().get_context_data(**kwargs)
        context["page_title"] = "Create study session"
        context["submit_label"] = "Create session"
        return context

    def get_success_url(self):
        """Redirect to the created session detail page."""
        return reverse("sessions:detail", kwargs={"pk": self.object.pk})


class StudySessionDetailView(LoginRequiredMixin, DetailView):
    """Display a user-owned study session and its notes."""

    model = StudySession
    template_name = "sessions/session_detail.html"
    context_object_name = "session"

    def get_queryset(self):
        """Return sessions scoped to the authenticated user."""
        return get_sessions_for_user(self.request.user)

    def get_context_data(self, **kwargs):
        """Add note form and latest insight to the detail context."""
        context = super().get_context_data(**kwargs)
        context.update(
            session_detail_context(
                study_session=self.object,
                user=self.request.user,
            )
        )
        return context


class StudySessionUpdateView(LoginRequiredMixin, UpdateView):
    """Update a user-owned study session."""

    model = StudySession
    form_class = StudySessionForm
    template_name = "sessions/session_form.html"
    context_object_name = "session"

    def get_queryset(self):
        """Return sessions scoped to the authenticated user."""
        return get_sessions_for_user(self.request.user)

    def form_valid(self, form):
        """Save a valid update and notify the user."""
        messages.success(self.request, "Study session updated successfully.")
        return super().form_valid(form)

    def get_context_data(self, **kwargs):
        """Add update-page labels to the form context."""
        context = super().get_context_data(**kwargs)
        context["page_title"] = "Edit study session"
        context["submit_label"] = "Save changes"
        context["study_session"] = self.object
        return context

    def get_success_url(self):
        """Redirect to the updated session detail page."""
        return reverse("sessions:detail", kwargs={"pk": self.object.pk})


class StudyNoteCreateView(LoginRequiredMixin, View):
    """Create a note under a user-owned study session."""

    http_method_names = ["post"]

    def post(self, request, pk: int):
        """Handle note creation for a study session."""
        study_session = get_session_for_user_or_404(request.user, pk)
        form = StudyNoteForm(request.POST)

        if form.is_valid():
            note = form.save(commit=False)
            note.session = study_session
            note.save()
            messages.success(request, "Study note added successfully.")
            return redirect("sessions:detail", pk=study_session.pk)

        messages.error(request, "Please correct the note form and try again.")
        return render(
            request,
            "sessions/session_detail.html",
            session_detail_context(
                study_session=study_session,
                user=request.user,
                note_form=form,
            ),
            status=400,
        )


class StudyNoteUpdateView(LoginRequiredMixin, View):
    """Update a note under a user-owned study session."""

    http_method_names = ["post"]

    def post(self, request, pk: int, note_pk: int):
        """Handle note updates for a study session."""
        note = get_note_for_user_or_404(request.user, pk, note_pk)
        study_session = note.session
        form = StudyNoteForm(request.POST, instance=note)

        if form.is_valid():
            form.save()
            messages.success(request, "Study note updated successfully.")
            return redirect("sessions:detail", pk=study_session.pk)

        messages.error(request, "Please correct the note form and try again.")
        return render(
            request,
            "sessions/session_detail.html",
            session_detail_context(
                study_session=study_session,
                user=request.user,
                edit_note_form=form,
                editing_note=note,
            ),
            status=400,
        )


class StudyNoteDeleteView(LoginRequiredMixin, View):
    """Delete a note under a user-owned study session."""

    http_method_names = ["post"]

    def post(self, request, pk: int, note_pk: int):
        """Handle note deletion for a study session."""
        note = get_note_for_user_or_404(request.user, pk, note_pk)
        study_session = note.session
        note.delete()
        messages.success(request, "Study note deleted successfully.")
        return redirect("sessions:detail", pk=study_session.pk)


session_list = StudySessionListView.as_view()
session_create = StudySessionCreateView.as_view()
session_detail = StudySessionDetailView.as_view()
session_update = StudySessionUpdateView.as_view()
session_add_note = StudyNoteCreateView.as_view()
session_update_note = StudyNoteUpdateView.as_view()
session_delete_note = StudyNoteDeleteView.as_view()
