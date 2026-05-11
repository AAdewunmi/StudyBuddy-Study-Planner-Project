"""View tests for study session workflows."""

from __future__ import annotations

from datetime import timedelta

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.sessions.factories import StudyNoteFactory, StudySessionFactory
from apps.sessions.models import StudyNote, StudySession
from apps.users.factories import CustomUserFactory

pytestmark = pytest.mark.django_db


def _session_form_data(**overrides):
    data = {
        "title": "Read Django docs",
        "subject": "Django",
        "status": StudySession.Status.PLANNED,
        "study_date": timezone.localdate().isoformat(),
        "duration_minutes": "45",
    }
    data.update(overrides)
    return data


def test_session_list_requires_login(client) -> None:
    """Anonymous users are redirected before viewing study sessions."""
    response = client.get(reverse("sessions:list"))

    assert response.status_code == 302
    assert response["Location"].startswith(f"{reverse('users:login')}?next=")


def test_session_list_shows_only_current_users_sessions(client) -> None:
    """The session list renders only sessions owned by the current user."""
    user = CustomUserFactory(email="list.owner@example.com")
    owned_session = StudySessionFactory(owner=user, title="Owned session")
    StudySessionFactory(title="Hidden session")
    client.force_login(user)

    response = client.get(reverse("sessions:list"))

    assert response.status_code == 200
    assert list(response.context["sessions"]) == [owned_session]
    assert b"Owned session" in response.content
    assert b"Hidden session" not in response.content


def test_session_create_page_renders(client) -> None:
    """The create page renders a study session form."""
    user = CustomUserFactory(email="create.page@example.com")
    client.force_login(user)

    response = client.get(reverse("sessions:create"))

    assert response.status_code == 200
    assert response.context["page_title"] == "Create study session"
    assert b"Session Details" in response.content


def test_session_create_persists_session_for_current_user(client) -> None:
    """A valid create request stores a session for the current user."""
    user = CustomUserFactory(email="create.owner@example.com")
    client.force_login(user)

    response = client.post(reverse("sessions:create"), _session_form_data())

    session = StudySession.objects.get(owner=user)
    assert response.status_code == 302
    assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
    assert session.title == "Read Django docs"
    assert session.subject == "Django"


def test_session_create_rerenders_invalid_form(client) -> None:
    """Invalid create requests show form errors without creating a session."""
    user = CustomUserFactory(email="create.invalid@example.com")
    client.force_login(user)

    response = client.post(
        reverse("sessions:create"),
        _session_form_data(duration_minutes="0"),
    )

    assert response.status_code == 200
    assert b"Ensure this value is greater than or equal to 1." in response.content
    assert not StudySession.objects.filter(owner=user).exists()


def test_session_detail_renders_session_and_notes(client) -> None:
    """The detail page renders one owned session and its notes."""
    user = CustomUserFactory(email="detail.owner@example.com")
    session = StudySessionFactory(owner=user, title="Essay outline")
    StudyNoteFactory(session=session, content="Drafted thesis evidence notes.")
    client.force_login(user)

    response = client.get(reverse("sessions:detail", kwargs={"pk": session.pk}))

    assert response.status_code == 200
    assert response.context["session"] == session
    assert b"Essay outline" in response.content
    assert b"Drafted thesis evidence notes." in response.content


def test_session_detail_rejects_other_users_session(client) -> None:
    """A user cannot view another user's session detail page."""
    user = CustomUserFactory(email="detail.viewer@example.com")
    other_session = StudySessionFactory()
    client.force_login(user)

    response = client.get(reverse("sessions:detail", kwargs={"pk": other_session.pk}))

    assert response.status_code == 404


def test_session_update_page_renders_existing_session(client) -> None:
    """The update page renders the selected session in the form."""
    user = CustomUserFactory(email="update.page@example.com")
    session = StudySessionFactory(owner=user, title="Original title")
    client.force_login(user)

    response = client.get(reverse("sessions:update", kwargs={"pk": session.pk}))

    assert response.status_code == 200
    assert response.context["session"] == session
    assert response.context["page_title"] == "Edit study session"
    assert b"Original title" in response.content


def test_session_update_saves_changes(client) -> None:
    """A valid update request changes an owned study session."""
    user = CustomUserFactory(email="update.owner@example.com")
    session = StudySessionFactory(owner=user, title="Original title")
    client.force_login(user)

    response = client.post(
        reverse("sessions:update", kwargs={"pk": session.pk}),
        _session_form_data(title="Updated title", subject="Algorithms"),
    )

    session.refresh_from_db()
    assert response.status_code == 302
    assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
    assert session.title == "Updated title"
    assert session.subject == "Algorithms"


def test_session_update_rerenders_invalid_form(client) -> None:
    """Invalid update requests leave the existing session unchanged."""
    user = CustomUserFactory(email="update.invalid@example.com")
    session = StudySessionFactory(owner=user, title="Original title")
    future_date = timezone.localdate() + timedelta(days=1)
    client.force_login(user)

    response = client.post(
        reverse("sessions:update", kwargs={"pk": session.pk}),
        _session_form_data(
            status=StudySession.Status.COMPLETED,
            study_date=future_date.isoformat(),
        ),
    )

    session.refresh_from_db()
    assert response.status_code == 200
    assert (
        b"Completed study sessions cannot be dated in the future." in response.content
    )
    assert session.title == "Original title"


def test_session_add_note_creates_note(client) -> None:
    """A valid note request attaches the note to the owned session."""
    user = CustomUserFactory(email="note.owner@example.com")
    session = StudySessionFactory(owner=user)
    client.force_login(user)

    response = client.post(
        reverse("sessions:add_note", kwargs={"pk": session.pk}),
        {"content": "Reviewed model relationships and form validation."},
    )

    note = StudyNote.objects.get(session=session)
    assert response.status_code == 302
    assert response["Location"] == reverse("sessions:detail", kwargs={"pk": session.pk})
    assert note.content == "Reviewed model relationships and form validation."


def test_session_add_note_rerenders_invalid_form(client) -> None:
    """Invalid note requests return the detail page with form errors."""
    user = CustomUserFactory(email="note.invalid@example.com")
    session = StudySessionFactory(owner=user)
    client.force_login(user)

    response = client.post(
        reverse("sessions:add_note", kwargs={"pk": session.pk}),
        {"content": "short"},
    )

    assert response.status_code == 400
    assert b"Study notes must contain at least 10 characters." in response.content
    assert not StudyNote.objects.filter(session=session).exists()
