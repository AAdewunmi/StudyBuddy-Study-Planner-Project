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

    def __init__(self, *args, **kwargs) -> None:
        """Keep rendered duration bounds aligned with domain validation."""
        super().__init__(*args, **kwargs)

        duration_field = self.fields["duration_minutes"]
        duration_field.min_value = 1
        duration_field.max_value = 1440
        duration_field.widget.attrs["min"] = 1
        duration_field.widget.attrs["max"] = 1440

    def clean_title(self) -> str:
        """Normalize the submitted study session title."""
        return self.cleaned_data["title"].strip()

    def clean_subject(self) -> str:
        """Normalize the submitted study session subject."""
        return self.cleaned_data["subject"].strip()


class StudyNoteForm(forms.ModelForm):
    """Form used to add and update notes on a study session."""

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

    def clean_content(self) -> str:
        """Normalize the submitted study note content."""
        return self.cleaned_data["content"].strip()
