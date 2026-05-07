
## `docs/authentication.md`

```markdown
# Authentication and Access Control

Sprint 1 introduces the StudyBuddy identity baseline.

The goal is to support a real SaaS product shape without overbuilding permissions before product workflows exist.

## User model

StudyBuddy uses `apps.users.CustomUser`.

The model extends Django's `AbstractUser` and changes the login identifier to email.

```python
USERNAME_FIELD = "email"