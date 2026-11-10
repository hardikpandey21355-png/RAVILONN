from typing import Any

from firebase_admin import auth as firebase_auth, firestore

from app.core.firestore import get_db, get_storage_bucket, run_transaction


class AccountDeletionError(Exception):
    status_code = 409


class AccountDeletionStorageUnavailable(AccountDeletionError):
    status_code = 503


class AdminAccountDeletionNotAllowed(AccountDeletionError):
    status_code = 403


def delete_user_account(
    uid: str,
    *,
    db: Any = None,
    storage_bucket: Any = None,
) -> dict[str, int]:
    if not isinstance(uid, str) or not uid or "/" in uid or len(uid) > 128:
        raise AccountDeletionError("Could not identify this account.")

    database = db or get_db()
    user_ref = database.collection("users").document(uid)
    user_snapshot = user_ref.get()
    user = user_snapshot.to_dict() if user_snapshot.exists else {}
    user = user or {}

    try:
        auth_user = firebase_auth.get_user(uid)
    except firebase_auth.UserNotFoundError:
        auth_user = None
    if auth_user is not None and (auth_user.custom_claims or {}).get("admin") is True:
        raise AdminAccountDeletionNotAllowed(
            "Admin accounts cannot be deleted from the player profile."
        )

    pending_withdrawals = [
        snapshot
        for snapshot in database.collection("withdrawals")
        .where("uid", "==", uid)
        .stream()
        if (snapshot.to_dict() or {}).get("status") == "pending"
    ]
    if pending_withdrawals:
        raise AccountDeletionError(
            "Resolve your pending withdrawal before deleting your account."
        )

    bucket = storage_bucket if storage_bucket is not None else get_storage_bucket()
    if bucket is None and user.get("upiShot") is True:
        raise AccountDeletionStorageUnavailable(
            "Account deletion is temporarily unavailable. Please try again later."
        )

    tournament_entries = list(
        database.collection("tournamentEntries").where("uid", "==", uid).stream()
    )
    removals: dict[tuple[str, str], Any] = {}

    def include(snapshots: Any) -> None:
        for snapshot in snapshots:
            removals[(snapshot.reference.path, snapshot.reference.id)] = (
                snapshot.reference
            )

    for collection_name in (
        "deposits",
        "transactions",
        "withdrawals",
        "paymentOrders",
        "tournamentResults",
        "tournamentSlotClaims",
        "notifications",
        "adminNotificationLogs",
        "adminWalletCredits",
        "gameUids",
    ):
        include(
            database.collection(collection_name)
            .where("uid", "==", uid)
            .stream()
        )

    include(tournament_entries)
    for field in ("uid", "adminUid", "target", "details.uid"):
        include(
            database.collection("auditLogs")
            .where(field, "==", uid)
            .stream()
        )

    rewards = list(user_ref.collection("appUpdateRewards").stream())
    include(rewards)
    bonus_campaigns = list(user_ref.collection("appBonusCampaigns").stream())
    include(bonus_campaigns)

    if user_snapshot.exists:
        removals[(user_ref.path, user_ref.id)] = user_ref
    for collection_name in ("wallets", "withdrawalLocks"):
        reference = database.collection(collection_name).document(uid)
        removals[(reference.path, reference.id)] = reference

    stored_files = (
        list(bucket.list_blobs(prefix=f"users/{uid}/")) if bucket is not None else []
    )
    for blob in stored_files:
        blob.delete()

    entries_by_tournament: dict[str, list[Any]] = {}
    for snapshot in tournament_entries:
        entry = snapshot.to_dict() or {}
        tournament_id = entry.get("tournamentId")
        if isinstance(tournament_id, str) and tournament_id:
            entries_by_tournament.setdefault(tournament_id, []).append(snapshot)

    entry_references = {
        (snapshot.reference.path, snapshot.reference.id)
        for snapshots in entries_by_tournament.values()
        for snapshot in snapshots
    }
    references = [
        reference
        for key, reference in removals.items()
        if key not in entry_references
    ]
    for offset in range(0, len(references), 450):
        batch = database.batch()
        for reference in references[offset : offset + 450]:
            batch.delete(reference)
        batch.commit()

    for tournament_id, snapshots in entries_by_tournament.items():
        tournament_ref = database.collection("tournaments").document(tournament_id)
        tournament_snapshot = tournament_ref.get()
        batch = database.batch()
        for snapshot in snapshots:
            batch.delete(snapshot.reference)
        if tournament_snapshot.exists:
            batch.update(
                tournament_ref,
                {
                    "joinedCount": firestore.Increment(-len(snapshots)),
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
            )
        batch.commit()

    if auth_user is not None:
        firebase_auth.delete_user(uid)

    return {
        "documentsDeleted": len(references)
        + sum(len(snapshots) for snapshots in entries_by_tournament.values()),
        "filesDeleted": len(stored_files),
        "tournamentsUpdated": len(entries_by_tournament),
    }


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
