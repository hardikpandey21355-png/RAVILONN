import argparse
import os
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore

backend_root = str(Path(__file__).resolve().parents[1])
if backend_root not in sys.path:
    sys.path.insert(0, backend_root)


def main() -> None:
    from app.services.settings_service import DEFAULT_SETTINGS

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--test-minimum",
        action="store_true",
        help="Set the existing settings/app minAdd value to 1 rupee.",
    )
    args = parser.parse_args()
    try:
        firebase_app = firebase_admin.get_app()
    except ValueError:
        credentials_path = (
            os.environ.get("FIREBASE_CREDENTIALS")
            or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        )
        certificate = (
            credentials.Certificate(credentials_path) if credentials_path else None
        )
        firebase_app = firebase_admin.initialize_app(
            credential=certificate,
            options={
                "projectId": os.environ.get("FIREBASE_PROJECT_ID", "ravilon-19a47")
            }
        )
    db = firestore.client(app=firebase_app)
    settings_ref = db.collection("settings").document("app")
    if settings_ref.get().exists:
        if args.test_minimum:
            settings_ref.set({"minAdd": 1}, merge=True)
            print("Updated settings/app minAdd to 1 rupee for testing.")
            return
        print("settings/app already exists; leaving it unchanged.")
        return
    settings_ref.set(DEFAULT_SETTINGS)
    print("Created settings/app with default wallet limits.")


if __name__ == "__main__":
    main()
