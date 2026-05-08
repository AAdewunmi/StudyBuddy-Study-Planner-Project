# StudyBuddy Domain Model

StudyBuddy is centred on user-owned study activity. Sprint 2 introduces the core workflow that lets a user create a study session, add notes, and see personal metrics on the dashboard.

## Core ownership rule

Every study session belongs to one authenticated user. The application enforces ownership at query level through selectors, not by hiding data in templates.

The core selector is:

```text
StudySession.objects.filter(owner=request.user)