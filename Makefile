.PHONY: build up down restart logs migrate makemigrations test check deploy-check collectstatic shell superuser lint format ci

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d

logs:
	docker compose logs -f web

migrate:
	docker compose exec web python manage.py migrate

makemigrations:
	docker compose exec web python manage.py makemigrations

test:
	docker compose exec web pytest -q

check:
	docker compose exec web python manage.py check

deploy-check:
	docker compose exec web python manage.py check --deploy --settings=config.settings.production

collectstatic:
	docker compose exec web python manage.py collectstatic --noinput --settings=config.settings.production

shell:
	docker compose exec web python manage.py shell

superuser:
	docker compose exec web python manage.py createsuperuser

lint:
	docker compose exec web ruff check .

format:
	docker compose exec web black .

ci:
	docker compose exec web ruff check .
	docker compose exec web black --check .
	docker compose exec web python manage.py check
	docker compose exec web python manage.py migrate
	docker compose exec web pytest -q