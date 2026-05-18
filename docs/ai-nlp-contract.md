# StudyBuddy AI/NLP Contract

## Purpose

StudyBuddy includes a lightweight AI/NLP feature that helps users review their
study notes. The feature is designed for an early SaaS MVP where usefulness,
determinism, explainability, and testability matter more than model complexity.

The system does not use a large language model, external API, background
worker, or opaque prediction service. It uses deterministic text processing so
the same source notes produce the same insight outputs.

## Current Project Status

The current project includes:

- `apps.insights.models.StudyInsight`
- `apps.insights.admin.StudyInsightAdmin`
- `apps.insights.services.generate_insight_for_session`
- `apps.insights.selectors.get_latest_session_insight`
- `apps.insights.selectors.get_user_insights`
- authenticated insight generation at `insights:generate`
- session detail rendering for the latest generated insight
- an insights list view scoped to the authenticated user
- deterministic text normalisation and source hashing helpers
- deterministic keyword extraction
- extractive summary generation
- rule-based confidence scoring
- deterministic explanation building
- model, admin, NLP, service, selector, route, permission, and UI tests

## Product Behaviour

A signed-in user should be able to open one of their own study sessions and
generate an insight from the notes attached to that session.

The generated insight contains:

- an extractive summary
- ranked keywords
- a confidence score from 0 to 100
- an explanation of how the insight was produced
- a source hash representing the normalised note text

The insight is stored in the database and can be viewed again later from the
session detail workflow. If the source notes have not changed, the application
should reuse the existing insight instead of creating a duplicate row.

## Deterministic Contract

For the same source note text, the pipeline must produce the same:

- normalised text
- source hash
- keyword list
- summary
- confidence score
- explanation pattern

The source hash is generated from normalised note text using SHA-256. The hash
allows the application to detect whether notes have changed since the last
generated insight.

If a user generates an insight twice without changing the notes, StudyBuddy
should reuse the existing insight instead of creating a duplicate row.

## Input Scope

The Sprint 3 implementation analyses note content attached to a single study
session.

It does not analyse:

- notes from other users
- sessions owned by another user
- files or uploads
- global account history
- private profile fields
- external sources

## Text Normalisation

The pipeline lowercases text, trims whitespace, collapses repeated whitespace,
and tokenises alphanumeric terms.

Stop words are filtered before keyword extraction. Short terms are also removed
where they are unlikely to carry meaningful study context.

## Keyword Extraction

Keywords are selected using deterministic term frequency.

Ranking rules:

1. Higher frequency ranks first.
2. Alphabetical order breaks ties.
3. The result is capped by the configured keyword limit.

This is intentionally simple and explainable. It helps users see repeated
concepts without pretending to infer deep semantic meaning.

## Extractive Summary

The summary is extractive. It selects sentences from the user's own notes
rather than generating new claims.

Sentence scoring uses meaningful tokens and extracted keyword frequency.
High-signal sentences are selected, then returned in their original source
order so the summary remains readable.

When there is not enough content, the system returns a low-information message
instead of fabricating a useful-looking summary.

## Confidence Scoring

Confidence is rule-based. It reflects whether the input text contains enough
meaningful content to support a useful insight.

The score considers:

- meaningful token count
- unique meaningful token count
- keyword count
- whether a usable summary exists

Confidence labels:

- `Low` for scores below 45
- `Medium` for scores from 45 to 74
- `High` for scores from 75 to 100

The confidence score is not a probability, an intelligence score, or a claim of
factual correctness. It is a quality signal for the generated insight.

## Explanation

Every generated insight includes an explanation. The explanation tells the user:

- that keywords came from deterministic term frequency
- that the summary uses source sentences
- how many meaningful terms were analysed
- which keywords were detected
- when there was too little content to analyse properly

The explanation is part of the product contract. It avoids presenting the
result as smarter or more authoritative than it is.

## Persistence Rules

Study insights are stored in `StudyInsight`.

Current fields:

- `session`
- `summary`
- `keywords`
- `confidence`
- `explanation`
- `source_hash`
- `created_at`
- `updated_at`

`StudyInsight` does not store a separate `owner` field. Ownership is inherited
through `StudyInsight.session.owner`, matching the existing session and note
ownership model.

Uniqueness rule:

- one insight per session and source hash

Ownership rule:

- insight ownership is resolved through the parent session
- any generation service or view must ensure the session belongs to the
  requesting user before creating or returning an insight

Validation rules currently enforced by the model:

- `keywords` must be a list
- each keyword must be a string
- `confidence` must be between 0 and 100
- `source_hash` must be 64 characters

The NLP pipeline should generate `source_hash` values as valid SHA-256 hex
digests before creating a `StudyInsight`.

## Permission Rules

A user should only generate insights for their own sessions.

A user should only view insights attached to their own sessions.

Cross-user access should be blocked at query level in selectors and views by
filtering through `session__owner`.

## Testing Contract

Current tests cover:

- model persistence
- ownership inheritance through `session.owner`
- keyword field validation
- source hash length validation
- duplicate protection for `session` and `source_hash`
- admin owner display through the parent session
- admin keyword preview behaviour
- text normalisation
- source hashing
- keyword extraction
- extractive summary generation
- confidence scoring
- explanation behaviour
- idempotent insight generation through a service layer
- permission enforcement for generation and retrieval
- authenticated owner-only POST generation
- anonymous redirect behaviour
- POST-only route behaviour
- session detail visibility for the latest generated insight
- architecture boundaries that keep NLP internals out of views

## Known Limitations

This MVP feature is intentionally lightweight.

Current limitations:

- no LLM integration
- no semantic embeddings
- no topic clustering
- no background processing
- no evaluation dataset for summary quality
- no personalised recommendations
- no support for uploaded files
- no multilingual NLP tuning

These limitations are acceptable for the Sprint 3 MVP because the feature is
deterministic, cheap to run, easy to test, and honest in the UI.

## Verification Commands

Run targeted insight tests:

```bash
pytest apps/insights -q
```

Run project checks:

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
```
