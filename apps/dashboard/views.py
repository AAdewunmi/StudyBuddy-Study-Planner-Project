"""Views for authenticated StudyBuddy dashboard pages."""

from __future__ import annotations

from django.contrib.auth.decorators import login_required
from django.http import HttpRequest, HttpResponse
from django.shortcuts import render

from apps.dashboard.services import build_dashboard_context


@login_required
def index(request: HttpRequest) -> HttpResponse:
    """Render the authenticated StudyBuddy dashboard shell."""

    return render(
        request,
        "dashboard/index.html",
        build_dashboard_context(request.user),
    )
