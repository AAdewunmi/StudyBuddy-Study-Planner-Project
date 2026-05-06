# StudyBuddy UI Design System (Athenify-Inspired)
# Athenify URL: https://athenify.io/

## Purpose

This document defines the canonical UI/UX system for the StudyBuddy application.

All templates, components, and pages MUST follow this system to ensure:
- Visual consistency
- Predictable structure
- Reusable components
- Scalable frontend development

Codex or any code generation tool MUST treat this document as a contract.

---

## Core Design Principles

### 1. Layout Philosophy

- Use a **dashboard-first SaaS layout**
- Structure:
  - Sidebar (navigation)
  - Topbar (context/actions)
  - Main content area
- Content is always organised as:
  **Page → Section → Card → Action**

---

### 2. Spacing System

Use a consistent **8px spacing scale**:

| Token | Value |
|------|------|
| xs   | 4px  |
| sm   | 8px  |
| md   | 16px |
| lg   | 24px |
| xl   | 32px |
| xxl  | 48px |

Rules:
- Never use arbitrary spacing
- Always apply spacing via CSS classes
- Prefer padding over margin for internal layout

---

### 3. Typography

- Font: system-ui stack (fast, neutral, modern)
- Hierarchy:

| Element | Style |
|--------|------|
| Page Title | Large, bold |
| Section Title | Medium, semi-bold |
| Card Title | Small, bold |
| Body Text | Regular |
| Metadata | Small, muted |

Rules:
- Maintain strong visual hierarchy
- Avoid excessive font sizes
- Use weight instead of colour for emphasis

---

### 4. Colour System

Neutral-first palette:

- Background: very light grey
- Surface (cards): white
- Border: soft grey
- Text: near-black
- Accent: subtle (blue or indigo)

Rules:
- Avoid high saturation
- Use colour sparingly for actions and highlights
- Maintain high readability

---

### 5. Components

#### Cards
- Rounded corners
- Soft border
- Internal padding (md or lg)
- Used for ALL grouped content

#### Buttons
- Rounded
- Minimal styling
- Clear hover states

#### Sidebar
- Fixed width
- Vertical navigation
- Active item clearly highlighted

#### Sections
- Always have a title
- Contain 1+ cards
- Maintain vertical rhythm

---

### 6. Layout Rules

- Use grid or flex layouts
- Avoid deeply nested structures
- Maximum content width should be constrained
- Maintain whitespace around sections

---

### 7. Reusability Requirements

All UI must:
- Extend `/templates/base.html`
- Use shared styles from `/static/css/theme.css`
- Avoid duplication
- Be component-friendly

---

## Codex Usage Contract

When generating UI:

### MUST

- Follow this design system strictly
- Extend base template
- Use predefined spacing and component styles
- Produce semantic HTML

### MUST NOT

- Use inline styles
- Introduce new spacing scales
- Break layout hierarchy
- Invent new design patterns

---

## Canonical Prompt (Use This for All UI Generation)

Use Athenify.io as UI/UX inspiration.

Design requirements:
- Clean, minimal dashboard aesthetic
- Soft neutral colour palette (light greys, subtle accent colour)
- Generous whitespace and padding
- Rounded components (cards, buttons)
- Clear hierarchy (title → section → card → action)
- Modern SaaS layout (sidebar + main content)
- Consistent spacing scale (8px grid)

Tech constraints:
- Django templates + HTMX
- No inline styles
- Reusable components where possible

Follow the project design system defined in:
- /docs/design-system.md
- /templates/base.html
- /static/css/theme.css

Use Athenify-inspired design principles already defined there.

Output:
- Production-ready template
- Semantic HTML structure