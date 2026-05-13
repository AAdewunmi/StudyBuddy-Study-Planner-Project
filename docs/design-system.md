# StudyBuddy UI Design System

Source inspiration: https://athenify.io/

This document is the canonical UI contract for StudyBuddy templates. The goal
is not to copy Athenify verbatim. The goal is to give StudyBuddy the same
category feel: a polished study-product website with a bright marketing shell,
a blue brand accent, dark rounded calls to action, and dashboard views that make
study tracking feel motivating and useful.

The current Sprint 2 product workflow is documented in
`docs/codex-studybuddy-sprint-2-outline.md`. Template changes should stay
aligned with that outline.

## Visual Direction

StudyBuddy should feel like:

- A student-focused study tracker and planner.
- Clean, white, spacious, and product-led.
- More like a refined landing/product app than a generic admin panel.
- Built around visual dashboard previews, real study-session metrics, compact
  cards, progress pills, streaks, and study-session controls.

Avoid a plain left-sidebar SaaS layout for the public shell. Athenify's first viewport uses a top navigation bar, centered hero content, large product imagery, soft shadows, and very little background color.

## Layout Model

All templates must extend `/templates/base.html`.

The base template provides:

- White top navigation.
- Brand lockup on the left.
- Product/category navigation in the center.
- Authentication actions on the right.
- A constrained main content area.

Page content follows:

`Page shell -> Hero or Page Header -> Section -> Card -> Action`

Use the dashboard-app visual language inside cards, previews, and authenticated
dashboard content, not as the global frame.

## Color System

Use CSS variables from `/static/css/theme.css`.

Primary colors:

| Token | Purpose |
| --- | --- |
| `--color-page` | Overall page background |
| `--color-surface` | Cards, nav, panels |
| `--color-ink` | Main text |
| `--color-muted` | Supporting text |
| `--color-line` | Borders |
| `--color-blue` | Brand blue |
| `--color-dark` | Dark CTA and app sidebar |
| `--color-green` | Progress and success indicators |

Rules:

- Use white as the dominant page color.
- Use blue mainly for brand and small highlights.
- Use dark navy/black for primary CTAs.
- Use green only for progress, streaks, and positive study metrics.
- Do not use purple-first palettes or generic Bootstrap button colors.

## Typography

Use the system UI stack.

Hierarchy:

| Element | Style |
| --- | --- |
| Brand | Bold, blue, compact |
| Hero headline | Large, black, tight line-height |
| Page title | Strong, dashboard-like |
| Section eyebrow | Small, uppercase, muted blue/grey |
| Section title | Bold, medium-large |
| Card title | Small, bold |
| Metadata | Small, muted |

Hero copy should be direct and product-specific. Avoid generic filler.

## Spacing

Use the 8px scale only:

| Token | Value |
| --- | --- |
| xs | 4px |
| sm | 8px |
| md | 16px |
| lg | 24px |
| xl | 32px |
| xxl | 48px |
| xxxl | 72px |

Sections need generous vertical space. Cards stay compact and information dense.

## Components

### Header

- White background.
- Logo/brand left.
- Horizontal nav.
- Right-aligned login and dark pill CTA.
- Sticky positioning is allowed when it does not obscure content.

### Buttons

- `btn-ui`: white button with soft border.
- `btn-ui-primary`: dark navy pill, used for primary action.
- `btn-ui-blue`: brand-blue secondary action.

Buttons should be rounded pills, not rectangular admin buttons.

### Cards

- White surface.
- Soft grey border.
- 18-24px radius.
- Subtle shadow only for hero/product preview cards.
- Compact typography.

### Product Mockups

Athenify relies heavily on dashboard screenshots. StudyBuddy templates should use reusable HTML/CSS product mockups until real screenshots exist:

- Browser/device frame.
- Dark app sidebar inside the mockup.
- Dashboard heading.
- Metric strip.
- Study streak row.
- Progress bars.
- Chart-like panels.

This is a required visual pattern for public-facing pages.

### Authenticated Dashboard

The authenticated dashboard is a data-backed workflow, not a static preview.
It should use the same StudyBuddy visual language as the sessions and profile
templates:

- `container-ui` and `page-stack` for the page shell.
- `page-header`, `eyebrow`, `page-title`, and `page-subtitle` for the header.
- `card-grid`, `card-ui`, `metric-value`, and `metric-label` for metric cards.
- `mock-pill-row` and `mock-pill` for status and duration metadata.
- `quote-card` for empty states.
- `btn-ui btn-ui-primary` for the primary `sessions:create` action.

The dashboard template must only render values prepared by Python code. It must
not calculate counts, sums, filters, or ownership rules in the template.

Expected dashboard context:

| Context value | Purpose |
| --- | --- |
| `metrics.total_sessions` | Total sessions owned by the current user |
| `metrics.completed_sessions` | Completed sessions owned by the current user |
| `metrics.total_minutes` | Sum of the current user's study minutes |
| `metrics.note_count` | Notes attached to the current user's sessions |
| `recent_activity` | Recent user-owned study sessions |
| `roles` | Current user's product roles |

Dashboard responsibility split:

| Layer | Responsibility |
| --- | --- |
| `apps/sessions/selectors.py` | User-scoped session and note queries |
| `apps/sessions/services.py` | Session aggregate metrics |
| `apps/dashboard/services.py` | Dashboard context composition |
| `apps/dashboard/views.py` | Pass prepared context to the template |
| `templates/dashboard/index.html` | Render prepared values and links |

Recent activity cards should link to `sessions:detail`. Empty dashboard states
should link to `sessions:create` and explain why creating the first study
session is useful.

### Sections

Every major section must have either:

- An eyebrow plus title, or
- A clear section title.

Sections should not be floating cards. Cards belong inside sections.

## Template Rules

Must:

- Extend `base.html`.
- Use shared classes from `theme.css`.
- Use semantic HTML.
- Use card, section, button, metric, and mockup utilities.
- Keep all styling out of templates.
- Render prepared context values instead of calculating aggregates in templates.

Must not:

- Reintroduce a global sidebar shell.
- Use inline styles.
- Use arbitrary spacing.
- Use Bootstrap visual classes as the main design system.
- Use placeholder admin UI that lacks product context.
- Count, sum, filter, or enforce ownership rules in Django templates.

## Canonical Prompt

When creating or refactoring StudyBuddy templates:

Use Athenify.io as visual inspiration: white marketing shell, blue brand, dark rounded CTA, generous whitespace, large dashboard preview, compact metric cards, green progress indicators, and student-focused study tracking content.

Follow:

- `/docs/design-system.md`
- `/templates/base.html`
- `/static/css/theme.css`

Output production-ready Django templates that extend the base template and use only shared design-system classes.
