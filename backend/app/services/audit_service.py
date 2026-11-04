from typing import Any

from firebase_admin import firestore

from app.core.firestore import get_db


def log(adminUid: str, action: str, target: str, details: dict[str, Any]) -> str:
    record = {
        "adminUid": adminUid,
        "action": action,
        "target": target,
        "details": details,
        "createdAt": firestore.SERVER_TIMESTAMP,
    }
    return get_db().collection("auditLogs").add(record)[1].id
