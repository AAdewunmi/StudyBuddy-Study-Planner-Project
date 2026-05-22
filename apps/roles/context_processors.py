"""Template context helpers for role-aware navigation."""

from __future__ import annotations

from typing import Any

from django.http import HttpRequest

from apps.roles.permissions import user_has_role


def product_roles(request: HttpRequest) -> dict[str, Any]:
    """Expose lightweight role flags to shared templates."""
    return {
        "is_product_admin": user_has_role(request.user, "admin"),
    }
