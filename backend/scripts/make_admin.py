import argparse
import os

import firebase_admin
from firebase_admin import auth


def main() -> None:
    parser = argparse.ArgumentParser(description="Grant the Firebase admin claim to a user.")
    parser.add_argument("email", help="Email address of the Firebase user")
    email = parser.parse_args().email
    try:
        firebase_app = firebase_admin.get_app()
    except ValueError:
        firebase_app = firebase_admin.initialize_app(
            options={"projectId": os.environ.get("FIREBASE_PROJECT_ID", "ravilon-19a47")}
        )
    user = auth.get_user_by_email(email, app=firebase_app)
    auth.set_custom_user_claims(user.uid, {"admin": True}, app=firebase_app)
    print(f"Admin claim granted to {email} ({user.uid}).")


if __name__ == "__main__":
    main()
