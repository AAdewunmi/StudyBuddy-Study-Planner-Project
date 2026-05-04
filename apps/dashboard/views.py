"""Dashboard views."""

from __future__ import annotations

from django.contrib.auth.decorators import login_required
from django.shortcuts import render


@login_required
def index(request):
    """Render the authenticated dashboard shell."""
    return render(request, "dashboard/index.html")
