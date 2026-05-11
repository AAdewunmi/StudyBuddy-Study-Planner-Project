"""Forms for StudyBuddy study session and note workflows."""

from __future__ import annotations

from django import forms

from apps.sessions.models import StudyNote, StudySession


class StudySessionForm(forms.ModelForm):
    """Form used to create and update study sessions."""

    class Meta:
        """Form metadata binding the form to StudySession."""

        model = StudySession
        fields = [
            "title",
            "subject",
            "status",
            "study_date",
            "duration_minutes",
        ]
        labels = {
            "duration_minutes": "Duration",
        }
        widgets = {
            "title": forms.TextInput(
                attrs={
                    "placeholder": "Revise Django model relationships",
                }
            ),
            "subject": forms.TextInput(
                attrs={
                    "placeholder": "Django, statistics, biology",
                }
            ),
            "study_date": forms.DateInput(
                attrs={
                    "type": "date",
                }
            ),
            "duration_minutes": forms.NumberInput(
                attrs={
                    "min": 1,
                    "max": 1440,
                    "placeholder": "90",
                }
            ),
        }


class StudyNoteForm(forms.ModelForm):
    """Form used to add notes to a study session."""

    class Meta:
        """Form metadata binding the form to StudyNote."""

        model = StudyNote
        fields = [
            "content",
        ]
        widgets = {
            "content": forms.Textarea(
                attrs={
                    "rows": 5,
                    "placeholder": (
                        "Capture what you studied, key ideas, blockers, "
                        "or revision points."
                    ),
                }
            ),
        }
