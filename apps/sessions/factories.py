"""factory_boy factories for the sessions app tests."""

from __future__ import annotations

import factory
from django.utils import timezone
from factory.django import DjangoModelFactory

from apps.sessions.models import StudyNote, StudySession
from apps.users.factories import CustomUserFactory


class StudySessionFactory(DjangoModelFactory):
    """Test factory for StudySession."""

    class Meta:
        """Factory metadata binding this factory to StudySession."""

        model = StudySession

    owner = factory.SubFactory(CustomUserFactory)
    title = factory.Sequence(lambda number: f"Study session {number}")
    subject = "Django"
    status = StudySession.Status.PLANNED
    study_date = factory.LazyFunction(timezone.localdate)
    duration_minutes = 45


class StudyNoteFactory(DjangoModelFactory):
    """Test factory for StudyNote."""

    class Meta:
        """Factory metadata binding this factory to StudyNote."""

        model = StudyNote

    session = factory.SubFactory(StudySessionFactory)
    content = "Reviewed model relationships, forms, and ownership checks."
