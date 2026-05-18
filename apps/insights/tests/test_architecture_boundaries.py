"""Architecture boundary tests for the insights workflow."""

from __future__ import annotations

import ast
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
APPS_ROOT = PROJECT_ROOT / "apps"

FORBIDDEN_NLP_MODULE_PREFIX = "apps.insights.nlp"
FORBIDDEN_NLP_IMPORT_NAMES = {
    "LOW_INFORMATION_SUMMARY",
    "build_explanation",
    "confidence_label",
    "extract_keywords",
    "meaningful_tokens",
    "normalise_text",
    "score_confidence",
    "source_text_hash",
    "split_paragraphs",
    "split_sentences",
    "summarise_text",
}


def find_view_nlp_import_violations(
    *,
    project_root: Path,
    apps_root: Path,
) -> list[str]:
    """Return view imports that cross the insights NLP boundary."""
    violations: list[str] = []

    for view_path in sorted(apps_root.glob("**/views.py")):
        tree = ast.parse(view_path.read_text(encoding="utf-8"), filename=str(view_path))

        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                violations.extend(
                    f"{view_path.relative_to(project_root)}:{node.lineno} imports "
                    f"{alias.name}"
                    for alias in node.names
                    if alias.name == FORBIDDEN_NLP_MODULE_PREFIX
                    or alias.name.startswith(f"{FORBIDDEN_NLP_MODULE_PREFIX}.")
                )

            if isinstance(node, ast.ImportFrom):
                module = node.module or ""

                if module == FORBIDDEN_NLP_MODULE_PREFIX or module.startswith(
                    f"{FORBIDDEN_NLP_MODULE_PREFIX}."
                ):
                    violations.append(
                        f"{view_path.relative_to(project_root)}:{node.lineno} imports "
                        f"from {module}"
                    )

                violations.extend(
                    f"{view_path.relative_to(project_root)}:{node.lineno} imports "
                    f"NLP helper {alias.name}"
                    for alias in node.names
                    if alias.name in FORBIDDEN_NLP_IMPORT_NAMES
                )

    return violations


def test_detects_views_that_import_insights_nlp_helpers(tmp_path: Path) -> None:
    """Boundary violations should report the view file and forbidden import."""
    view_path = tmp_path / "apps" / "example" / "views.py"
    view_path.parent.mkdir(parents=True)
    view_path.write_text(
        "\n".join(
            [
                "import apps.insights.nlp.summarisation",
                "from apps.insights.nlp.keyword_extraction import extract_keywords",
            ]
        ),
        encoding="utf-8",
    )

    violations = find_view_nlp_import_violations(
        project_root=tmp_path,
        apps_root=tmp_path / "apps",
    )

    assert violations == [
        "apps/example/views.py:1 imports apps.insights.nlp.summarisation",
        "apps/example/views.py:2 imports from apps.insights.nlp.keyword_extraction",
        "apps/example/views.py:2 imports NLP helper extract_keywords",
    ]


def test_views_do_not_import_insights_nlp_helpers() -> None:
    """Views should call insight services instead of importing NLP internals."""
    assert (
        find_view_nlp_import_violations(
            project_root=PROJECT_ROOT,
            apps_root=APPS_ROOT,
        )
        == []
    )
