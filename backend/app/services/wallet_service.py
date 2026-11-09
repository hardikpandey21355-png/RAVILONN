from typing import Any

from firebase_admin import firestore

from app.core.firestore import get_db, run_transaction
from app.services.user_service import AccountOnHold


BUCKETS = ("deposited", "bonus", "winnings")


def apply(uid: str, changes: dict[str, Any], tx: Any) -> dict[str, Any]:
    db = get_db()
    wallet_ref = db.collection("wallets").document(uid)
    snapshot = wallet_ref.get(transaction=tx)
    wallet = snapshot.to_dict() if snapshot.exists else {}
    deltas = changes.get("deltas")
    if not isinstance(deltas, dict) or not deltas:
        raise ValueError("Wallet changes must include bucket deltas.")
    if not set(deltas).issubset(BUCKETS):
        raise ValueError("Wallet changes contain an unknown balance bucket.")

    updated: dict[str, int] = {}
    for bucket in BUCKETS:
        current = _rupees(wallet.get(bucket, 0), bucket)
        delta = deltas.get(bucket, 0)
        if isinstance(delta, bool) or not isinstance(delta, int):
            raise ValueError("Wallet amounts must be whole rupees.")
        updated[bucket] = current + delta
        if updated[bucket] < 0:
            raise InsufficientFunds

    ledger_ref = db.collection("transactions").document()
    amount = _rupees(changes.get("amt"), "amt")
    if amount <= 0:
        raise ValueError("Amount must be at least 1 rupee.")
    direction = changes.get("dir")
    if direction not in ("in", "out"):
        raise ValueError("Ledger direction must be in or out.")
    entry = {
        "uid": uid,
        "kind": _required_text(changes.get("kind"), "kind"),
        "title": _required_text(changes.get("title"), "title"),
        "amt": amount,
        "dir": direction,
        "status": _required_text(changes.get("status", "paid"), "status"),
        "ref": str(changes.get("ref", "")),
        "balanceAfter": sum(updated.values()),
        "createdAt": firestore.SERVER_TIMESTAMP,
    }

    tx.set(
        wallet_ref,
        {**updated, "updatedAt": firestore.SERVER_TIMESTAMP},
        merge=True,
    )
    tx.create(ledger_ref, entry)
    return {**updated, "total": sum(updated.values()), "ledgerId": ledger_ref.id}


def debit_entry_fee(uid: str, fee: int, ref: str) -> dict[str, Any]:
    _positive_integer(fee)
    db = get_db()

    def operation(tx: Any) -> dict[str, Any]:
        _ensure_not_held(db, uid, tx)
        wallet_snapshot = db.collection("wallets").document(uid).get(transaction=tx)
        wallet = wallet_snapshot.to_dict() if wallet_snapshot.exists else {}
        return apply(
            uid,
            {
                "deltas": entry_fee_deltas(wallet, fee),
                "kind": "entry_fee",
                "title": "Entry fee",
                "amt": fee,
                "dir": "out",
                "status": "paid",
                "ref": ref,
            },
            tx,
        )

    return run_transaction(db, operation)


def entry_fee_deltas(wallet: dict[str, Any], fee: int) -> dict[str, int]:
    _positive_integer(fee)
    remaining = fee
    deltas = {bucket: 0 for bucket in BUCKETS}
    for bucket in BUCKETS:
        available = _rupees(wallet.get(bucket, 0), bucket)
        taken = min(available, remaining)
        deltas[bucket] = -taken
        remaining -= taken
    if remaining:
        raise InsufficientFunds
    return deltas


def credit(
    uid: str,
    bucket: str,
    amt: int,
    title: str = "Wallet credit",
    kind: str = "credit",
    ref: str = "",
) -> dict[str, Any]:
    if bucket not in BUCKETS:
        raise ValueError("Unknown wallet bucket.")
    _positive_integer(amt)
    db = get_db()

    def operation(tx: Any) -> dict[str, Any]:
        _ensure_not_held(db, uid, tx)
        return apply(
            uid,
            {
                "deltas": {bucket: amt},
                "kind": kind,
                "title": title,
                "amt": amt,
                "dir": "in",
                "status": "paid",
                "ref": ref,
            },
            tx,
        )

    return run_transaction(db, operation)


def claim_app_update_bonus(
    uid: str,
    build_number: int,
    *,
    campaign_build_number: int,
    enabled: bool,
    db: Any = None,
) -> bool:
    if not enabled or build_number < campaign_build_number:
        return False

    database = db or get_db()
    claim_ref = (
        database.collection("users")
        .document(uid)
        .collection("appUpdateRewards")
        .document(f"build_{campaign_build_number}")
    )

    def operation(tx: Any) -> bool:
        if claim_ref.get(transaction=tx).exists:
            return False
        _ensure_not_held(database, uid, tx)
        apply(
            uid,
            {
                "deltas": {"bonus": 10},
                "kind": "app_update_bonus",
                "title": "APK update bonus",
                "amt": 10,
                "dir": "in",
                "status": "paid",
                "ref": f"apk-update-build-{campaign_build_number}",
            },
            tx,
        )
        tx.create(
            claim_ref,
            {
                "buildNumber": campaign_build_number,
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        return True

    return run_transaction(database, operation)


def wallet_for(uid: str, db: Any = None) -> dict[str, int]:
    database = db or get_db()
    snapshot = database.collection("wallets").document(uid).get()
    wallet = snapshot.to_dict() if snapshot.exists else {}
    values = {bucket: _rupees(wallet.get(bucket, 0), bucket) for bucket in BUCKETS}
    return {**values, "total": sum(values.values())}


def _ensure_not_held(db: Any, uid: str, tx: Any) -> None:
    snapshot = db.collection("users").document(uid).get(transaction=tx)
    user = snapshot.to_dict() if snapshot.exists else {}
    if user.get("isHeld") is True or user.get("is_held") is True:
        raise AccountOnHold


def _rupees(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{field} must be a whole number of rupees.")
    return value


def _positive_integer(value: Any) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise ValueError("Amount must be a whole number of at least 1 rupee.")


def _required_text(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field} is required.")
    return value.strip()


class InsufficientFunds(Exception):
    pass
