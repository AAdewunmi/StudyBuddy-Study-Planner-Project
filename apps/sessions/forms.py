"""
Forms for the StudyBuddy session workflow.
"""

from django import forms

from apps.sessions.models import StudyNote, StudySession


class StudySessionForm(forms.ModelForm):
    """
    Form used to create and update study sessions.
    """

    class Meta:
        """
        Form metadata binding the form to StudySession.
        """

        model = StudySession
        fields = [
            "title",
            "subject",
            "status",
            "study_date",
            "duration_minutes",
        ]
        widgets = {
            "title": forms.TextInput(
                attrs={
                    "class": "form-control",
                    "placeholder": "Example: Revise Django model relationships",
                }
            ),
            "subject": forms.TextInput(
                attrs={
                    "class": "form-control",
                    "placeholder": "Example: Django, PostgreSQL, Algorithms",
                }
            ),
            "status": forms.Select(
                attrs={
                    "class": "form-select",
                }
            ),
            "study_date": forms.DateInput(
                attrs={
                    "class": "form-control",
                    "type": "date",
                }
            ),
            "duration_minutes": forms.NumberInput(
                attrs={
                    "class": "form-control",
                    "min": 1,
                    "max": 1440,
                }
            ),
        }


class StudyNoteForm(forms.ModelForm):
    """
    Form used to add notes to a study session.
    """

    class Meta:
        """
        Form metadata binding the form to StudyNote.
        """

        model = StudyNote
        fields = [
            "content",
        ]
        widgets = {
            "content": forms.Textarea(
                attrs={
                    "class": "form-control",
                    "rows": 5,
                    "placeholder": "Capture what you studied, key ideas, blockers, or revision points.",
                }
            ),
        }