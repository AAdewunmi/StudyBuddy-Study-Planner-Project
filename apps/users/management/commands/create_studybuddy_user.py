"""
Create sample StudyBuddy users with product roles.

Run this command from the project root:

    python manage.py create_studybuddy_user

Docker example:

    docker compose exec -T web python manage.py create_studybuddy_user \
        --settings=config.settings.local

The command creates 10 sample users:

- 6 students
- 3 tutors
- 1 admin

All users are stored in the configured PostgreSQL database. The admin sample is
created as a Django superuser and receives the product admin role. Students and
tutors remain regular users and receive their matching product roles.
"""

from __future__ import annotations

from dataclasses import dataclass

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from apps.roles.models import Role

DEFAULT_PASSWORD = "StrongPassword123!"


@dataclass(frozen=True)
class RoleDefinition:
    """Configuration for a supported StudyBuddy product role."""

    slug: str
    display_name: str
    description: str
    is_staff: bool = False
    is_superuser: bool = False


@dataclass(frozen=True)
class SampleUser:
    """A sample user to create for local product inspection."""

    email: str
    role: str
    first_name: str
    last_name: str


ROLE_DEFINITIONS = {
    "student": RoleDefinition(
        slug="student",
        display_name="Student",
        description="Student role for StudyBuddy learners.",
    ),
    "tutor": RoleDefinition(
        slug="tutor",
        display_name="Tutor",
        description="Tutor role for StudyBuddy teaching support.",
    ),
    "admin": RoleDefinition(
        slug="admin",
        display_name="Admin",
        description="Admin role for StudyBuddy product administration.",
        is_staff=True,
        is_superuser=True,
    ),
}

SAMPLE_USERS = (
    SampleUser("student1@example.com", "student", "Ada", "Student"),
    SampleUser("student2@example.com", "student", "Grace", "Student"),
    SampleUser("student3@example.com", "student", "Katherine", "Student"),
    SampleUser("student4@example.com", "student", "Dorothy", "Student"),
    SampleUser("student5@example.com", "student", "Mary", "Student"),
    SampleUser("student6@example.com", "student", "Evelyn", "Student"),
    SampleUser("tutor1@example.com", "tutor", "Alan", "Tutor"),
    SampleUser("tutor2@example.com", "tutor", "Linus", "Tutor"),
    SampleUser("tutor3@example.com", "tutor", "Barbara", "Tutor"),
    SampleUser("admin@example.com", "admin", "StudyBuddy", "Admin"),
)


class Command(BaseCommand):
    """Create sample users with StudyBuddy role assignments."""

    help = (
        "Create 10 sample StudyBuddy users split across student, tutor, and "
        "admin product roles."
    )

    def add_arguments(self, parser) -> None:
        """Register command-line arguments."""
        parser.add_argument(
            "--password",
            default=DEFAULT_PASSWORD,
            help=(
                "Password to assign to all sample users. "
                f"Default: {DEFAULT_PASSWORD}"
            ),
        )

    def handle(self, *args, **options) -> None:
        """Create or update all sample users and print a console receipt."""
        password = options["password"]
        roles = {
            role_key: self._get_or_create_role(role_definition)
            for role_key, role_definition in ROLE_DEFINITIONS.items()
        }

        self.stdout.write("Creating StudyBuddy sample users...")
        self.stdout.write(f"default_password={password}")
        self.stdout.write("")
        self.stdout.write("email | role | username | is_staff | is_superuser | action")

        created_count = 0
        updated_count = 0

        for sample_user in SAMPLE_USERS:
            role_definition = ROLE_DEFINITIONS[sample_user.role]
            user, created = self._create_or_update_user(
                sample_user=sample_user,
                password=password,
                role_definition=role_definition,
            )
            self._assign_single_product_role(user, roles[sample_user.role])

            if created:
                created_count += 1
                action = "created"
            else:
                updated_count += 1
                action = "updated"

            self.stdout.write(
                f"{user.email} | {sample_user.role} | {user.username} | "
                f"{user.is_staff} | {user.is_superuser} | {action}"
            )

        self.stdout.write("")
        self.stdout.write(
            self.style.SUCCESS(
                "StudyBuddy sample users ready: "
                f"{created_count} created, {updated_count} updated, "
                f"{len(SAMPLE_USERS)} total."
            )
        )

    def _create_or_update_user(
        self,
        *,
        sample_user: SampleUser,
        password: str,
        role_definition: RoleDefinition,
    ):
        """Create a new user or update an existing sample user."""
        User = get_user_model()
        email = sample_user.email.lower()
        user = User.objects.filter(email__iexact=email).first()

        if user is None:
            create_kwargs = {
                "email": email,
                "password": password,
                "first_name": sample_user.first_name,
                "last_name": sample_user.last_name,
            }

            if role_definition.is_superuser:
                user = User.objects.create_superuser(**create_kwargs)
            else:
                user = User.objects.create_user(**create_kwargs)

            return user, True

        user.email = email
        user.first_name = sample_user.first_name
        user.last_name = sample_user.last_name
        user.is_staff = role_definition.is_staff
        user.is_superuser = role_definition.is_superuser
        user.set_password(password)
        user.save()

        return user, False

    def _get_or_create_role(self, role_definition: RoleDefinition) -> Role:
        """Ensure the product role exists before assigning it to sample users."""
        role, _created = Role.objects.get_or_create(
            slug=role_definition.slug,
            defaults={
                "display_name": role_definition.display_name,
                "description": role_definition.description,
            },
        )

        return role

    def _assign_single_product_role(self, user, role: Role) -> None:
        """Assign one sample product role and remove other sample role labels."""
        user.studybuddy_roles.remove(
            *Role.objects.filter(slug__in=ROLE_DEFINITIONS).exclude(pk=role.pk)
        )
        user.studybuddy_roles.add(role)
