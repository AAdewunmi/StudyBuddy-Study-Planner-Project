#!/usr/bin/env bash
#
# Sprint 3 Day 2: Keyword extraction and text normalisation verification.
#
# Purpose:
#   Console-only verification for deterministic NLP text processing and keyword
#   extraction. This runbook uses the Docker/PostgreSQL stack and the current
#   consolidated NLP test files.
#
# Execution:
#   chmod +x docs/sprint-runbook/sprint-3/sprint-3-day-2.sh
#   ./docs/sprint-runbook/sprint-3/sprint-3-day-2.sh
#
# Optional overrides:
#   PROJECT_ROOT=/path/to/StudyBuddy-Study-Planner-Project ./docs/sprint-runbook/sprint-3/sprint-3-day-2.sh
#   TEST_SETTINGS_MODULE=config.settings.test ./docs/sprint-runbook/sprint-3/sprint-3-day-2.sh
#   LOCAL_SETTINGS_MODULE=config.settings.local ./docs/sprint-runbook/sprint-3/sprint-3-day-2.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

PROJECT_ROOT="${PROJECT_ROOT:-$DEFAULT_PROJECT_ROOT}"
TEST_SETTINGS_MODULE="${TEST_SETTINGS_MODULE:-config.settings.test}"
LOCAL_SETTINGS_MODULE="${LOCAL_SETTINGS_MODULE:-config.settings.local}"

print_step() {
  printf "\n==> %s\n\n" "$1"
}

run() {
  printf '$ %s\n' "$*"
  "$@"
}

print_step "Verify repository root"
run cd "$PROJECT_ROOT"
printf "Repository root: %s\n" "$(pwd)"

print_step "Confirm Sprint 3 Day 2 files exist"

required_files=(
  "apps/insights/nlp/__init__.py"
  "apps/insights/nlp/text_processing.py"
  "apps/insights/nlp/keyword_extraction.py"
  "apps/insights/tests/test_nlp_keyword_extraction.py"
  "apps/insights/tests/test_nlp_text_processing.py"
  "docs/ai-nlp-contract.md"
)

for file_path in "${required_files[@]}"; do
  if [[ ! -f "$file_path" ]]; then
    printf "MISSING: %s\n" "$file_path"
    exit 1
  fi

  printf "FOUND: %s\n" "$file_path"
done

print_step "Confirm obsolete mixed NLP test file is absent"

obsolete_files=(
  "apps/insights/tests/test_keyword_extraction.py"
)

for file_path in "${obsolete_files[@]}"; do
  if [[ -e "$file_path" ]]; then
    printf "OBSOLETE FILE PRESENT: %s\n" "$file_path"
    exit 1
  fi

  printf "ABSENT: %s\n" "$file_path"
done

print_step "Build and start Docker/PostgreSQL stack"
run docker compose up -d --build
run docker compose ps

print_step "Run Django system check"
run docker compose exec -T web python manage.py check --settings="$LOCAL_SETTINGS_MODULE"

print_step "Confirm NLP modules import correctly"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.keyword_extraction import extract_keywords
from apps.insights.nlp.text_processing import (
    meaningful_tokens,
    normalise_text,
    source_text_hash,
    tokenize,
)

print("text_processing imports verified")
print("keyword_extraction imports verified")
print("NLP module import verification complete")
PY

print_step "Verify text normalisation behaviour"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.text_processing import normalise_text

result = normalise_text("  Django    Testing\nWorkflow  ")

assert result == "django testing workflow", result

print("Normalised text:", result)
print("Text normalisation verified")
PY

print_step "Verify tokenisation removes punctuation"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.text_processing import tokenize

result = tokenize("Django, pytest, and PostgreSQL!")

assert result == ["django", "pytest", "and", "postgresql"], result

print("Tokens:", result)
print("Tokenisation verified")
PY

print_step "Verify stop-word and short-token filtering"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.text_processing import meaningful_tokens

result = meaningful_tokens("The API is on and the UI is in sync.")

assert result == ["api", "sync"], result

print("Meaningful tokens:", result)
print("Stop-word filtering verified")
PY

print_step "Verify source hash stability"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.text_processing import source_text_hash

first_hash = source_text_hash("Django    testing workflow")
second_hash = source_text_hash(" django testing   workflow ")

assert first_hash == second_hash, (first_hash, second_hash)
assert len(first_hash) == 64, first_hash

print("Source hash:", first_hash)
print("Source hash stability verified")
PY

print_step "Verify keyword extraction ranks repeated terms first"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.keyword_extraction import extract_keywords

result = extract_keywords(
    "Django testing testing pytest Django testing database.",
    limit=3,
)

assert result == ["testing", "django", "database"], result

print("Ranked keywords:", result)
print("Repeated-term ranking verified")
PY

print_step "Verify deterministic keyword tie-breaking"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.keyword_extraction import extract_keywords

result = extract_keywords("zebra alpha beta zebra alpha beta", limit=3)

assert result == ["alpha", "beta", "zebra"], result

print("Tie-break keywords:", result)
print("Alphabetical tie-breaking verified")
PY

print_step "Verify keyword limit handling"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.keyword_extraction import extract_keywords

result = extract_keywords(
    "django pytest postgres docker templates bootstrap views models",
    limit=4,
)

assert len(result) == 4, result
assert result == ["bootstrap", "django", "docker", "models"], result

print("Limited keywords:", result)
print("Keyword limit verified")
PY

print_step "Verify empty and low-information input handling"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.keyword_extraction import extract_keywords

none_result = extract_keywords(None)
empty_result = extract_keywords("")
stop_word_result = extract_keywords("and the of to")
short_token_result = extract_keywords("AI ML UX")
zero_limit_result = extract_keywords("biology biology chemistry", limit=0)
negative_limit_result = extract_keywords("biology biology chemistry", limit=-1)

assert none_result == [], none_result
assert empty_result == [], empty_result
assert stop_word_result == [], stop_word_result
assert short_token_result == [], short_token_result
assert zero_limit_result == [], zero_limit_result
assert negative_limit_result == [], negative_limit_result

print("None input keywords:", none_result)
print("Empty input keywords:", empty_result)
print("Stop-word-only keywords:", stop_word_result)
print("Short-token-only keywords:", short_token_result)
print("Zero-limit keywords:", zero_limit_result)
print("Negative-limit keywords:", negative_limit_result)
print("Low-information keyword handling verified")
PY

print_step "Verify keyword extraction is stable across repeated runs"

docker compose exec -T web python manage.py shell --settings="$LOCAL_SETTINGS_MODULE" <<'PY'
from apps.insights.nlp.keyword_extraction import extract_keywords

text = (
    "Django testing protects the workflow. "
    "Django testing confirms database behaviour. "
    "Pytest testing keeps changes safe."
)

first = extract_keywords(text, limit=5)
second = extract_keywords(text, limit=5)
third = extract_keywords(text, limit=5)

assert first == second == third, (first, second, third)

print("Repeated run one:", first)
print("Repeated run two:", second)
print("Repeated run three:", third)
print("Deterministic keyword extraction verified")
PY

print_step "Confirm AI/NLP contract document sections"

required_sections=(
  "## Current Scope"
  "## Deterministic Contract"
  "## Text Normalisation"
  "## Keyword Extraction"
  "## Testing Contract"
)

for section in "${required_sections[@]}"; do
  if ! grep -Fq "$section" docs/ai-nlp-contract.md; then
    printf "MISSING SECTION: %s\n" "$section"
    exit 1
  fi

  printf "FOUND: %s\n" "$section"
done

printf "\nAI/NLP contract section check is a smoke check for expected headings.\n"

print_step "Run Sprint 3 Day 2 NLP keyword and text-processing tests"
run docker compose exec -T web env DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" \
  pytest \
  apps/insights/tests/test_nlp_keyword_extraction.py \
  apps/insights/tests/test_nlp_text_processing.py \
  -q

print_step "Run all current insights tests"
run docker compose exec -T web env DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" pytest apps/insights -q

print_step "Run full project test suite"
run docker compose exec -T web env DJANGO_SETTINGS_MODULE="$TEST_SETTINGS_MODULE" pytest -q

print_step "Final receipt"

cat <<'RECEIPT'
Repository root verified.
Sprint 3 Day 2 files verified.
Obsolete mixed NLP test file is absent.
Docker/PostgreSQL stack is running.
Django system check passed.
NLP modules import correctly.
Text normalisation verified.
Tokenisation verified.
Stop-word filtering verified.
Source hash stability verified.
Repeated-term keyword ranking verified.
Alphabetical tie-breaking verified.
Keyword limit handling verified.
Empty and low-information input handling verified.
Deterministic repeated-run behaviour verified.
AI/NLP contract document headings verified.
Sprint 3 Day 2 NLP keyword and text-processing tests pass.
Current insights tests pass.
Full project regression suite passes.
Sprint 3 Day 2 verification complete.
RECEIPT
