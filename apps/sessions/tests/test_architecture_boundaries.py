"""Architecture boundary tests for the sessions workflow."""

from __future__ import annotations

import ast
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
SESSIONS_VIEWS_PATH = PROJECT_ROOT / "apps" / "sessions" / "views.py"
SESSION_MODEL_NAMES = {"StudyNote", "StudySession"}


def find_direct_session_manager_uses(
    *,
    project_root: Path,
    view_path: Path,
) -> list[str]:
    """Return direct session model manager usage from the view layer."""
    violations: list[str] = []
    tree = ast.parse(view_path.read_text(encoding="utf-8"), filename=str(view_path))

    for node in ast.walk(tree):
        if (
            isinstance(node, ast.Attribute)
            and node.attr == "objects"
            and isinstance(node.value, ast.Name)
            and node.value.id in SESSION_MODEL_NAMES
        ):
            violations.append(
                f"{view_path.relative_to(project_root)}:{node.lineno} uses "
                f"{node.value.id}.objects"
            )

    return violations


def test_detects_direct_session_manager_usage_in_views(tmp_path: Path) -> None:
    """Boundary violations should report direct model manager usage."""
    view_path = tmp_path / "apps" / "sessions" / "views.py"
    view_path.parent.mkdir(parents=True)
    view_path.write_text(
        "\n".join(
            [
                "StudySession.objects.filter(owner=request.user)",
                "StudyNote.objects.get(pk=note_pk)",
            ]
        ),
        encoding="utf-8",
    )

    assert find_direct_session_manager_uses(
        project_root=tmp_path,
        view_path=view_path,
    ) == [
        "apps/sessions/views.py:1 uses StudySession.objects",
        "apps/sessions/views.py:2 uses StudyNote.objects",
    ]


def test_session_views_use_selectors_for_model_queries() -> None:
    """Session views should use selectors instead of direct model managers."""
    assert (
        find_direct_session_manager_uses(
            project_root=PROJECT_ROOT,
            view_path=SESSIONS_VIEWS_PATH,
        )
        == []
    )
