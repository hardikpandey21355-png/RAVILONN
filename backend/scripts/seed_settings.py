import argparse
import os
import sys
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

backend_root = str(Path(__file__).resolve().parents[1])
if backend_root not in sys.path:
    sys.path.insert(0, backend_root)


def main() -> None:
    from app.services.settings_service import DEFAULT_SETTINGS

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--min-add",
        type=int,
        help="Set settings/app minAdd without changing the other settings.",
    )
    args = parser.parse_args()
    if args.min_add is not None and args.min_add < 1:
        parser.error("--min-add must be at least 1 rupee.")
    load_dotenv(Path(backend_root) / ".env")
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
        if args.min_add is not None:
            settings_ref.set({"minAdd": args.min_add}, merge=True)
            print(f"Updated settings/app minAdd to {args.min_add} rupees.")
            return
        print("settings/app already exists; leaving it unchanged.")
        return
    settings = dict(DEFAULT_SETTINGS)
    if args.min_add is not None:
        settings["minAdd"] = args.min_add
    settings_ref.set(settings)
    print("Created settings/app with default wallet limits.")


if __name__ == "__main__":
    main()
