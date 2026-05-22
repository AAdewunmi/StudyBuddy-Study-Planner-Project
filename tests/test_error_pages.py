"""Custom error page coverage."""

from __future__ import annotations

import pytest
from django.core.exceptions import PermissionDenied, SuspiciousOperation
from django.http import HttpRequest, HttpResponse
from django.test import override_settings
from django.urls import path

from config.urls import urlpatterns as project_urlpatterns


def restricted_view(request: HttpRequest) -> HttpResponse:
    """Raise a permission error for the 403 handler."""
    raise PermissionDenied


def bad_request_view(request: HttpRequest) -> HttpResponse:
    """Raise a bad request error for the 400 handler."""
    raise SuspiciousOperation("Invalid request.")


def server_error_view(request: HttpRequest) -> HttpResponse:
    """Raise an unexpected error for the 500 handler."""
    raise RuntimeError("Unexpected error.")


urlpatterns = [
    path("bad-request/", bad_request_view),
    path("restricted/", restricted_view),
    path("server-error/", server_error_view),
] + project_urlpatterns


pytestmark = pytest.mark.django_db


@override_settings(DEBUG=False, ROOT_URLCONF=__name__)
def test_custom_400_page_renders(client) -> None:
    """Bad requests render the StudyBuddy 400 page."""
    response = client.get("/bad-request/")

    assert response.status_code == 400
    assert b"Request could not be processed" in response.content
    assert b"StudyBuddy" in response.content


@override_settings(DEBUG=False, ROOT_URLCONF=__name__)
def test_custom_403_page_renders(client) -> None:
    """Permission failures render the StudyBuddy 403 page."""
    response = client.get("/restricted/")

    assert response.status_code == 403
    assert b"You cannot view this page" in response.content
    assert b"StudyBuddy" in response.content


@override_settings(DEBUG=False, ROOT_URLCONF=__name__)
def test_custom_404_page_renders(client) -> None:
    """Missing pages render the StudyBuddy 404 page."""
    response = client.get("/missing-page/")

    assert response.status_code == 404
    assert b"This page is not in StudyBuddy" in response.content
    assert b"StudyBuddy" in response.content


@override_settings(DEBUG=False, ROOT_URLCONF=__name__)
def test_custom_500_page_renders(client) -> None:
    """Unexpected errors render the StudyBuddy 500 page."""
    client.raise_request_exception = False

    response = client.get("/server-error/")

    assert response.status_code == 500
    assert b"Something went wrong" in response.content
    assert b"StudyBuddy" in response.content
