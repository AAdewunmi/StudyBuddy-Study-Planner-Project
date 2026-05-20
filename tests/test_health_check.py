"""Tests for the StudyBuddy deployment health check."""

from __future__ import annotations

import pytest
from django.db import OperationalError


@pytest.mark.django_db
def test_health_check_returns_ok_when_database_is_available(client):
    """The health check should report ok when the database accepts a query."""

    response = client.get("/health/")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["service"] == "studybuddy"
    assert response.json()["checks"]["database"] == "ok"


def test_health_check_rejects_non_get_methods(client):
    """The health check should remain read-only for monitoring clients."""

    response = client.post("/health/")

    assert response.status_code == 405


def test_health_check_returns_degraded_when_database_is_unavailable(
    client,
    monkeypatch,
):
    """The health check should expose database failure with a 503 response."""

    from config import urls as config_urls

    class BrokenConnection:
        """Small test double that raises the same error as a failed DB call."""

        def cursor(self):
            """Raise an OperationalError when code tries to open a cursor."""

            raise OperationalError("database unavailable")

    monkeypatch.setattr(config_urls, "connection", BrokenConnection())

    response = client.get("/health/")

    assert response.status_code == 503
    assert response.json()["status"] == "degraded"
    assert response.json()["checks"]["database"] == "unavailable"