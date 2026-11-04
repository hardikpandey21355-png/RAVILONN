from typing import Any, Callable, TypeVar
import os

import firebase_admin
from firebase_admin import credentials, firestore, storage
from flask import current_app


T = TypeVar("T")


def get_db() -> Any:
    injected = current_app.config.get("FIRESTORE_CLIENT")
    if injected is not None:
        return injected

    firebase_app = _get_firebase_app()
    return firestore.client(app=firebase_app)


def _get_firebase_app() -> Any:
    try:
        return firebase_admin.get_app()
    except ValueError:
        credentials_path = (
            current_app.config.get("FIREBASE_CREDENTIALS")
            or os.environ.get("FIREBASE_CREDENTIALS", "")
            or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", "")
        )
        certificate = credentials.Certificate(credentials_path) if credentials_path else None
        return firebase_admin.initialize_app(
            credential=certificate,
            options={"projectId": current_app.config["FIREBASE_PROJECT_ID"]},
        )


def run_transaction(db: Any, callback: Callable[[Any], T]) -> T:
    transaction = db.transaction()
    return firestore.transactional(callback)(transaction)


def get_storage_bucket() -> Any:
    bucket_name = current_app.config.get("STORAGE_BUCKET", "").strip()
    if not bucket_name:
        return None

    firebase_app = _get_firebase_app()
    return storage.bucket(bucket_name, app=firebase_app)
