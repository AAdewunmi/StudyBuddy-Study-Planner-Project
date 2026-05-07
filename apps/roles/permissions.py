"""Reusable role-aware permission helpers."""

from __future__ import annotations

from collections.abc import Iterable, Callable
from functools import wraps
from typing import Any

from django.core.exceptions import PermissionDenied
from django.http import HttpRequest, HttpResponse


def user_has_role(user: Any, role_slug: str) -> bool:
    """Return whether a user has the requested role slug."""
    if not getattr(user, "is_authenticated", False):
        return False

    if getattr(user, "is_superuser", False):
        return True

    return user.roles.filter(slug=role_slug).exists()


def user_has_any_role(user: Any, role_slugs: Iterable[str]) -> bool:
    """Return whether a user has at least one of the requested role slugs."""
    return any(user_has_role(user, role_slug) for role_slug in role_slugs)


def role_required(role_slug: str) -> Callable:
    """Decorate a view so only users with a role can access it."""

    def decorator(view_func: Callable) -> Callable:
        """Wrap a Django view with a role check."""

        @wraps(view_func)
        def wrapped_view(
            request: HttpRequest, *args: Any, **kwargs: Any
        ) -> HttpResponse:
            """Run the role check before calling the wrapped view."""
            if not user_has_role(request.user, role_slug):
                raise PermissionDenied

            return view_func(request, *args, **kwargs)

        return wrapped_view

    return decorator