"""Initial migration for deterministic study insights."""

from __future__ import annotations

import django.core.validators
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):
    """Create the StudyInsight persistence model."""

    initial = True

    dependencies = [
        ("study_sessions", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="StudyInsight",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("summary", models.TextField()),
                ("keywords", models.JSONField(default=list)),
                (
                    "confidence",
                    models.PositiveSmallIntegerField(
                        validators=[
                            django.core.validators.MinValueValidator(0),
                            django.core.validators.MaxValueValidator(100),
                        ],
                    ),
                ),
                ("explanation", models.TextField()),
                ("source_hash", models.CharField(db_index=True, max_length=64)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "session",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="insights",
                        to="study_sessions.studysession",
                    ),
                ),
            ],
            options={
                "ordering": ["-created_at", "-id"],
            },
        ),
        migrations.AddConstraint(
            model_name="studyinsight",
            constraint=models.UniqueConstraint(
                fields=("session", "source_hash"),
                name="unique_insight_per_session_source",
            ),
        ),
    ]
