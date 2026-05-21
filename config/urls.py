"""URL configuration for the StudyBuddy SaaS MVP."""

from __future__ import annotations

from django.conf import settings
from django.contrib import admin
from django.db import OperationalError, connection
from django.http import JsonResponse
from django.urls import include, path
from django.views.decorators.http import require_GET
from django.views.generic import TemplateView


@require_GET
def health_check(request):
    """Return service health and database reachability for deployment checks."""

    database_status = "ok"
    response_status = 200

    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except OperationalError:
        database_status = "unavailable"
        response_status = 503

    payload = {
        "status": "ok" if response_status == 200 else "degraded",
        "service": "studybuddy",
        "release": getattr(settings, "RELEASE_SHA", "local"),
        "checks": {
            "database": database_status,
        },
    }
    return JsonResponse(payload, status=response_status)


urlpatterns = [
    path("", TemplateView.as_view(template_name="home.html"), name="home"),
    path("admin/", admin.site.urls),
    path("health/", health_check, name="health-check"),
    path("users/", include("apps.users.urls")),
    path("dashboard/", include("apps.dashboard.urls")),
    path("sessions/", include("apps.sessions.urls")),
    path("insights/", include("apps.insights.urls")),
]
