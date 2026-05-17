#!/usr/bin/env bash

# Sprint 3 Wednesday Console-Only Verification Runbook
#
# Purpose:
#   Verify Sprint 3 Wednesday: extractive summaries, confidence scoring, and
#   user-facing NLP explanations.
#
# Execution:
#   From the repository root:
#
#     chmod +x docs/sprint-runbook/sprint-3/sprint-3-day-3.sh
#     ./docs/sprint-runbook/sprint-3/sprint-3-day-3.sh
#
# Optional environment overrides:
#
#     PROJECT_ROOT=/path/to/repo \
#     TEST_SETTINGS_MODULE=config.settings.test \
#     LOCAL_SETTINGS_MODULE=config.settings.local \
#     ./docs/sprint-runbook/sprint-3/sprint-3-day-3.sh

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/Users/adrianadewunmi/VSCODE/StudyBuddy-Study-Planner-Project}"
TEST_SETTINGS_MODULE="${TEST_SETTINGS_MODULE:-config.settings.test}"
LOCAL_SETTINGS_MODULE="${LOCAL_SETTINGS_MODULE:-config.settings.local}"

print_step() {
  printf "\n==> %s\n\n" "$1"
}

run() {
  printf '$'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}

print_step "Verify repository root"
run cd "$PROJECT_ROOT"
printf "Repository root: %s\n" "$(pwd)"

print_step "Confirm Sprint 3 Day 3 files exist"

required_files=(
  "apps/insights/nlp/summarisation.py"
  "apps/insights/nlp/confidence.py"
  "apps/insights/nlp/explanations.py"
  "apps/insights/tests/test_summarisation.py"
  "apps/insights/tests/test_confidence.py"
  "apps/insights/tests/test_explanations.py"
  "docs/ai-nlp-contract.md"
)

for file_path in "${required_files[@]}"; do
  if [[ ! -f "$file_path" ]]; then
    printf "MISSING: %s\n" "$file_path"
    exit 1
  fi

  printf "FOUND: %s\n" "$file_path"
done

print_step "Build and start Docker/PostgreSQL stack"
run docker compose up -d --build
run docker compose ps

print_step "Run Django system check"
run docker compose exec -T web python manage.py check --settings="$LOCAL_SETTINGS_MODULE"

print_step "Confirm summarisation, confidence, and explanation modules import correctly"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.confidence import confidence_label, score_confidence
from apps.insights.nlp.explanations import build_explanation
from apps.insights.nlp.summarisation import LOW_INFORMATION_SUMMARY, summarise_text

print("summarisation imports verified")
print("confidence imports verified")
print("explanations imports verified")
print("Sprint 3 Day 3 NLP module import verification complete")
PY

print_step "Verify extractive summary selects a high-signal source sentence"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.summarisation import summarise_text

text = (
    "Today I opened the dashboard. "
    "Django testing confirms that Django views and Django forms work. "
    "I also reviewed a short note."
)

result = summarise_text(text, max_sentences=1)
expected = "Django testing confirms that Django views and Django forms work."

assert result == expected, result

print("Summary:", result)
print("High-signal extractive summary verified")
PY

print_step "Verify extractive summary preserves source order"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.summarisation import summarise_text

text = (
    "Database database transactions keep study notes consistent. "
    "Django forms validate study sessions. "
    "Database database constraints protect ownership rules."
)

result = summarise_text(text, max_sentences=2)
expected = (
    "Database database transactions keep study notes consistent. "
    "Database database constraints protect ownership rules."
)

assert result == expected, result

print("Source-ordered summary:", result)
print("Source-order preservation verified")
PY

print_step "Verify extractive summary only uses source note sentences"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.summarisation import summarise_text
from apps.insights.nlp.text_processing import split_sentences

text = (
    "Photosynthesis photosynthesis uses chlorophyll to convert light into glucose. "
    "Cell respiration releases stored energy during revision. "
    "Photosynthesis depends on carbon dioxide and water."
)

result = summarise_text(text, max_sentences=2)
source_sentences = split_sentences(text)
summary_sentences = split_sentences(result)

assert summary_sentences, result
assert all(sentence in source_sentences for sentence in summary_sentences), result
assert "mitochondria" not in result, result

print("Grounded summary:", result)
print("Source-sentence grounding verified")
PY

print_step "Verify low-information summary handling"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.summarisation import LOW_INFORMATION_SUMMARY, summarise_text

empty_result = summarise_text("")
none_result = summarise_text(None)
zero_sentence_result = summarise_text("Django testing workflow.", max_sentences=0)

assert empty_result == LOW_INFORMATION_SUMMARY, empty_result
assert none_result == LOW_INFORMATION_SUMMARY, none_result
assert zero_sentence_result == LOW_INFORMATION_SUMMARY, zero_sentence_result

print("Empty input summary:", empty_result)
print("None input summary:", none_result)
print("Zero-sentence summary:", zero_sentence_result)
print("Low-information summary handling verified")
PY

print_step "Verify summary generation is stable across repeated runs"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.summarisation import summarise_text

text = (
    "Django tests protect session workflows. "
    "Database constraints protect ownership behaviour. "
    "Django forms validate user input. "
    "Pytest confirms persistence and permissions."
)

first = summarise_text(text, max_sentences=2)
second = summarise_text(text, max_sentences=2)
third = summarise_text(text, max_sentences=2)

assert first == second == third, (first, second, third)

print("Repeated summary one:", first)
print("Repeated summary two:", second)
print("Repeated summary three:", third)
print("Deterministic summarisation verified")
PY

print_step "Verify confidence score returns zero for empty input"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.confidence import score_confidence

result = score_confidence("", [], "There is not enough content.")

assert result == 0, result

print("Empty input confidence:", result)
print("Zero-confidence handling verified")
PY

print_step "Verify confidence score stays within bounds"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.confidence import score_confidence

text = " ".join(["django testing database workflow"] * 20)

result = score_confidence(
    text,
    ["django", "testing", "database", "workflow"],
    "Django testing database workflow.",
)

assert 0 <= result <= 100, result

print("Bounded confidence:", result)
print("Confidence bounds verified")
PY

print_step "Verify confidence scoring is repeatable"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.confidence import score_confidence

text = (
    "Django testing confirms reliable session workflows. "
    "Database-backed notes improve review quality."
)
keywords = ["django", "testing", "database"]
summary = "Django testing confirms reliable session workflows."

scores = [score_confidence(text, keywords, summary) for _ in range(5)]

assert len(set(scores)) == 1, scores

print("Repeated confidence scores:", scores)
print("Deterministic confidence scoring verified")
PY

print_step "Verify richer note content scores higher than weak note content"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.confidence import score_confidence

weak = score_confidence("Django.", ["django"], "Django.")
strong = score_confidence(
    (
        "Django testing confirms reliable session workflows. "
        "Database-backed notes improve review quality. "
        "Pytest verifies permissions and persistence behaviour."
    ),
    ["django", "testing", "database", "pytest", "permissions"],
    "Django testing confirms reliable session workflows.",
)

assert strong > weak, (weak, strong)

print("Weak confidence:", weak)
print("Strong confidence:", strong)
print("Confidence quality progression verified")
PY

print_step "Verify low-information summary is not rewarded as usable"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.confidence import score_confidence
from apps.insights.nlp.summarisation import LOW_INFORMATION_SUMMARY

text = (
    "Django testing confirms reliable session workflows. "
    "Database-backed notes improve review quality."
)
keywords = ["django", "testing", "database"]

with_fallback_summary = score_confidence(text, keywords, LOW_INFORMATION_SUMMARY)
with_extract_summary = score_confidence(
    text,
    keywords,
    "Django testing confirms reliable session workflows.",
)

assert with_extract_summary > with_fallback_summary, (
    with_fallback_summary,
    with_extract_summary,
)

print("Fallback-summary confidence:", with_fallback_summary)
print("Extractive-summary confidence:", with_extract_summary)
print("Low-information summary confidence penalty verified")
PY

print_step "Verify confidence labels"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.confidence import confidence_label

assert confidence_label(0) == "Low"
assert confidence_label(44) == "Low"
assert confidence_label(45) == "Medium"
assert confidence_label(74) == "Medium"
assert confidence_label(75) == "High"
assert confidence_label(100) == "High"

print("0 ->", confidence_label(0))
print("44 ->", confidence_label(44))
print("45 ->", confidence_label(45))
print("74 ->", confidence_label(74))
print("75 ->", confidence_label(75))
print("100 ->", confidence_label(100))
print("Confidence label boundaries verified")
PY

print_step "Verify explanation for useful note content"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.explanations import build_explanation

text = (
    "Django testing confirms reliable session workflows. "
    "Database-backed notes improve review quality."
)

result = build_explanation(
    text=text,
    keywords=["django", "testing", "database"],
    confidence=72,
)

lower_result = result.lower()

assert "medium confidence" in lower_result, result
assert "meaningful terms" in lower_result, result
assert "term frequency" in lower_result, result
assert "deterministic tie-breaking" in lower_result, result
assert "original notes" in lower_result, result
assert "rather than generated claims" in lower_result, result
assert "django, testing, database" in lower_result, result

print("Explanation:", result)
print("Useful-content explanation verified")
PY

print_step "Verify explanation for low-information note content"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.explanations import build_explanation

result = build_explanation(
    text="",
    keywords=[],
    confidence=0,
)

lower_result = result.lower()

assert "low confidence" in lower_result, result
assert "not contain enough note text" in lower_result, result
assert "add more detailed notes" in lower_result, result

print("Low-information explanation:", result)
print("Low-information explanation verified")
PY

print_step "Confirm AI/NLP contract document sections"

required_sections=(
  "## Current Project Status"
  "## Deterministic Contract"
  "## Extractive Summary"
  "## Confidence Scoring"
  "## Explanation"
  "## Testing Contract"
)

for section in "${required_sections[@]}"; do
  if ! grep -Fq "$section" docs/ai-nlp-contract.md; then
    printf "MISSING SECTION: %s\n" "$section"
    exit 1
  fi

  printf "FOUND: %s\n" "$section"
done

print_step "Confirm AI/NLP contract includes Wednesday rules"

required_contract_phrases=(
  "The summary is extractive."
  "rather than generating new claims"
  "When there is not enough content"
  "Confidence is rule-based."
  "The confidence score is not a probability"
  "Every generated insight includes an explanation."
  "The explanation is part of the product contract."
  "explanation behaviour"
)

for phrase in "${required_contract_phrases[@]}"; do
  if ! grep -Fq "$phrase" docs/ai-nlp-contract.md; then
    printf "MISSING CONTRACT PHRASE: %s\n" "$phrase"
    exit 1
  fi

  printf "FOUND: %s\n" "$phrase"
done

print_step "Run Sprint 3 Day 3 NLP summarisation, confidence, and explanation tests"

run docker compose exec -T web env DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" pytest \
  apps/insights/tests/test_summarisation.py \
  apps/insights/tests/test_confidence.py \
  apps/insights/tests/test_explanations.py \
  -q

print_step "Run all current insights tests"
run docker compose exec -T web env DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" pytest apps/insights -q

print_step "Run full project test suite"
run docker compose exec -T web env DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" pytest -q

print_step "Final receipt"

cat <<'RECEIPT'
Repository root verified.
Sprint 3 Day 3 files verified.
Docker/PostgreSQL stack is running.
Django system check passed.
Summarisation, confidence, and explanation modules import correctly.
High-signal extractive summary verified.
Source-order summary preservation verified.
Source-sentence grounding verified.
Low-information summary handling verified.
Deterministic repeated-run summarisation verified.
Zero-confidence handling verified.
Confidence bounds verified.
Deterministic confidence scoring verified.
Confidence quality progression verified.
Low-information summary confidence penalty verified.
Confidence label boundaries verified.
Useful-content explanation verified.
Low-information explanation verified.
AI/NLP contract document headings verified.
AI/NLP contract Wednesday rules verified.
Sprint 3 Day 3 NLP summarisation, confidence, and explanation tests pass.
Current insights tests pass.
Full project regression suite passes.
Sprint 3 Day 3 verification complete.
RECEIPT
