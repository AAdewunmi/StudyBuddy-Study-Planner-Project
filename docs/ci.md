# Continuous Integration

StudyBuddy uses GitHub Actions as the hosted CI quality gate for the MVP.

Workflow file:

```text
.github/workflows/ci.yml
```

## Hosted CI

The `CI` workflow runs on:

- pushes to `main`
- pull requests

The workflow uses:

- Ubuntu latest GitHub Actions runner
- Python 3.13
- PostgreSQL 16 Alpine service container
- `config.settings.test`
- `requirements.txt` for dependency installation

The hosted workflow currently runs these checks:

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py migrate --noinput
python -m ruff check .
python -m black . --check
python -m isort . --check-only
docker build -t studybuddy-ci .
python -m pytest --cov=apps --cov=config --cov-report=xml -q
```

After pytest completes, CI uploads `coverage.xml` to Codecov with
`codecov/codecov-action`.

## CI Environment

The GitHub Actions job sets these important environment values:

```text
DJANGO_SETTINGS_MODULE=config.settings.test
DJANGO_SECRET_KEY=ci-secret-key
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
DATABASE_URL=postgres://studybuddy:studybuddy@localhost:5432/studybuddy_test
```

The PostgreSQL service uses:

```text
POSTGRES_DB=studybuddy_test
POSTGRES_USER=studybuddy
POSTGRES_PASSWORD=studybuddy
```

## Codecov

Coverage upload requires the `CODECOV_TOKEN` GitHub Actions secret.

The workflow is configured with `fail_ci_if_error: true`, so a failed Codecov
upload fails CI. If Codecov is unavailable or the repository token is missing,
the test suite can pass while the CI job still fails at the upload step.

## Local CI-Style Checks

For local Docker-backed verification, use:

```bash
make ci
```

The local `make ci` target runs inside the `web` container and currently checks:

```bash
python -m black . --check
python -m ruff check .
python manage.py check --settings=config.settings.local
python manage.py makemigrations --check --dry-run --settings=config.settings.local
python manage.py migrate --noinput --settings=config.settings.local
env DJANGO_SETTINGS_MODULE=config.settings.test TEST_DATABASE_URL=postgres://studybuddy:studybuddy@db:5432/studybuddy_test pytest -q
```

This is intentionally a local CI-style verification chain, not an exact copy of
GitHub Actions. Hosted CI additionally checks isort directly, builds the Docker
image, runs pytest with coverage XML output, and uploads coverage to Codecov.

To run the hosted test command shape locally from Docker Compose:

```bash
docker compose exec -T web env DJANGO_SETTINGS_MODULE=config.settings.test pytest --cov=apps --cov=config --cov-report=xml -q
```

If running pytest from a host-side Python environment instead of inside the
container, point the test settings at Docker Compose's published PostgreSQL
port:

```bash
TEST_DATABASE_URL=postgres://studybuddy:studybuddy@localhost:5432/studybuddy_test python3 -m pytest --cov=apps --cov=config --cov-report=term-missing -q
```

## Import Ordering

Ruff is the primary lint command used by the Makefile, and hosted CI also runs
isort directly:

```bash
python -m ruff check .
python -m isort . --check-only
```
