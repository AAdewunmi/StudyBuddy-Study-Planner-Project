"""Views for authenticated StudyBuddy dashboard pages."""

from __future__ import annotations

from django.contrib.auth.decorators import login_required
from django.http import HttpRequest, HttpResponse
from django.shortcuts import render


@login_required
def index(request: HttpRequest) -> HttpResponse:
    """Render the authenticated StudyBuddy dashboard shell."""
    roles = request.user.roles.order_by("display_name")

    return render(
        request,
        "dashboard/index.html",
        {
            "roles": roles,
        },
    )
