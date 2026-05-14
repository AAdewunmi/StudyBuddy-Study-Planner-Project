# StudyBuddy AI/NLP Contract

## Purpose

StudyBuddy includes a lightweight AI/NLP feature that helps users review their study notes. The feature is designed for an early SaaS MVP where usefulness, determinism, explainability, and testability matter more than model complexity.

The system does not use a large language model, external API, background worker, or opaque prediction service. It uses deterministic text processing so the same source notes produce the same insight.

## Product Behaviour

A user can open one of their own study sessions and generate an insight from the notes attached to that session.

The generated insight contains:

- an extractive summary
- ranked keywords
- a confidence score from 0 to 100
- an explanation of how the insight was produced
- a source hash representing the normalised note text

The insight is stored in the database and can be viewed again later from the session detail page or the insights dashboard.

## Deterministic Contract

For the same source note text, the pipeline must produce the same:

- normalised text
- source hash
- keyword list
- summary
- confidence score
- explanation pattern

The source hash is generated from normalised note text using SHA-256. The hash allows the application to detect whether notes have changed since the last generated insight.

If a user generates an insight twice without changing the notes, StudyBuddy reuses the existing insight instead of creating a duplicate row.

## Input Scope

The Sprint 3 implementation analyses note content attached to a single study session.

It does not analyse:

- notes from other users
- sessions owned by another user
- files or uploads
- global account history
- private profile fields
- external sources

## Text Normalisation

The pipeline lowercases text, trims whitespace, collapses repeated whitespace, and tokenises alphanumeric terms.

Stop words are filtered before keyword extraction. Short terms are also removed where they are unlikely to carry meaningful study context.

## Keyword Extraction

Keywords are selected using deterministic term frequency.

Ranking rules:

1. Higher frequency ranks first.
2. Alphabetical order breaks ties.
3. The result is capped by the configured keyword limit.

This is intentionally simple and explainable. It helps users see repeated concepts without pretending to infer deep semantic meaning.

## Extractive Summary

The summary is extractive. It selects sentences from the user's own notes rather than generating new claims.

Sentence scoring uses meaningful tokens and extracted keyword frequency. High-signal sentences are selected, then returned in their original source order so the summary remains readable.

When there is not enough content, the system returns a low-information message instead of fabricating a useful-looking summary.

## Confidence Scoring

Confidence is rule-based. It reflects whether the input text contains enough meaningful content to support a useful insight.

The score considers:

- meaningful token count
- unique meaningful token count
- keyword count
- whether a usable summary exists

Confidence labels:

- `Low` for scores below 45
- `Medium` for scores from 45 to 74
- `High` for scores from 75 to 100

The confidence score is not a probability and does not claim factual correctness. It is a quality signal for the generated insight.

## Explanation

Every generated insight includes an explanation. The explanation tells the user:

- that keywords came from deterministic term frequency
- that the summary uses source sentences
- how many meaningful terms were analysed
- which keywords were detected
- when there was too little content to analyse properly

The explanation is part of the product contract. It avoids presenting the result as smarter or more authoritative than it is.

## Persistence Rules

Study insights are stored in `StudyInsight`.

Required fields:

- `owner`
- `session`
- `summary`
- `keywords`
- `confidence`
- `explanation`
- `source_hash`
- `created_at`
- `updated_at`

Uniqueness rule:

- one insight per owner, session, and source hash

Ownership rule:

- insight owner must match the session owner

## Permission Rules

A user can only generate insights for their own sessions.

A user can only view their own insights.

Cross-user access is blocked at query level in selectors and views.

## Testing Contract

Sprint 3 tests cover:

- model persistence
- owner/session validation
- keyword extraction
- text normalisation
- source hashing
- summary generation
- confidence scoring
- explanation behaviour
- idempotent insight generation
- permission enforcement
- insights dashboard visibility

## Known Limitations

This MVP feature is intentionally lightweight.

Current limitations:

- no semantic embeddings
- no topic clustering
- no cross-session insight history
- no background processing
- no evaluation dataset for summary quality
- no personalised recommendations
- no support for uploaded files
- no multilingual NLP tuning

These limitations are acceptable for the Sprint 3 MVP because the feature is deterministic, cheap to run, easy to test, and honest in the UI.

## Verification Commands

Run targeted NLP tests:

```bash
pytest apps/insights -q