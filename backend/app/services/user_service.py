from typing import Any

from firebase_admin import firestore

from app.core.firestore import get_db, run_transaction


def get_or_create_user(claims: dict[str, Any]) -> dict[str, Any]:
    uid = claims.get("uid") or claims.get("sub")
    if not isinstance(uid, str) or not uid:
        raise ValueError("Verified Firebase claims must contain a user ID.")

    db = get_db()
    user_ref = db.collection("users").document(uid)

    def operation(tx: Any) -> dict[str, Any]:
        user_snapshot = user_ref.get(transaction=tx)
        user = user_snapshot.to_dict() if user_snapshot.exists else {}
        if user.get("isHeld") is True or user.get("is_held") is True:
            raise AccountOnHold

        updates = {
            "uid": uid,
            "name": _claim_string(claims.get("name")) or user.get("name") or "Player",
            "email": _claim_string(claims.get("email")) or user.get("email") or "",
            "picture": _claim_string(claims.get("picture")) or user.get("picture") or "",
        }
        defaults = {
            "ign": "",
            "gameUid": "",
            "gameOk": False,
            "upi": "",
            "upiShot": False,
            "isHeld": False,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
        if not user_snapshot.exists:
            updates.update(defaults)
        updates["updatedAt"] = firestore.SERVER_TIMESTAMP
        tx.set(user_ref, updates, merge=True)
        return {**user, **updates}

    try:
        return run_transaction(db, operation)
    except AccountOnHold:
        raise


class AccountOnHold(Exception):
    pass


def _claim_string(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""

