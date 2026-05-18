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


def test_views_do_not_import_insights_nlp_helpers() -> None:
    """Views should call insight services instead of importing NLP internals."""
    violations = []

    for view_path in sorted(APPS_ROOT.glob("**/views.py")):
        tree = ast.parse(view_path.read_text(encoding="utf-8"), filename=str(view_path))

        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                violations.extend(
                    f"{view_path.relative_to(PROJECT_ROOT)}:{node.lineno} imports "
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
                        f"{view_path.relative_to(PROJECT_ROOT)}:{node.lineno} imports "
                        f"from {module}"
                    )

                violations.extend(
                    f"{view_path.relative_to(PROJECT_ROOT)}:{node.lineno} imports "
                    f"NLP helper {alias.name}"
                    for alias in node.names
                    if alias.name in FORBIDDEN_NLP_IMPORT_NAMES
                )

    assert violations == []
