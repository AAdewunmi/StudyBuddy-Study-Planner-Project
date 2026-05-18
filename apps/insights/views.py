"""Views for generating and displaying study insights."""

from __future__ import annotations

from django.contrib import messages
from django.contrib.auth.mixins import LoginRequiredMixin
from django.shortcuts import get_object_or_404, redirect
from django.views import View
from django.views.generic import ListView

from apps.insights.models import StudyInsight
from apps.insights.selectors import get_user_insights
from apps.insights.services import generate_insight_for_session
from apps.sessions.models import StudySession


class InsightListView(LoginRequiredMixin, ListView):
    """Display the authenticated user's generated insights."""

    model = StudyInsight
    template_name = "insights/insight_list.html"
    context_object_name = "insights"
    paginate_by = 12

    def get_queryset(self):
        """Return insights scoped to the authenticated user."""
        return get_user_insights(self.request.user)


class GenerateInsightView(LoginRequiredMixin, View):
    """Generate or reuse an insight for a user-owned session."""

    http_method_names = ["post"]

    def post(self, request, session_id: int):
        """Handle insight generation for a study session."""
        session = get_object_or_404(
            StudySession,
            pk=session_id,
            owner=request.user,
        )

        result = generate_insight_for_session(
            session=session,
            requested_by=request.user,
        )

        if result.created:
            messages.success(request, "Study insight generated successfully.")
        else:
            messages.info(
                request,
                "Existing insight reused because the notes have not changed.",
            )

        return redirect("sessions:detail", pk=session.pk)
