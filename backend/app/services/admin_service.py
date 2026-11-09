from datetime import datetime, timezone
import re
from typing import Any
from zoneinfo import ZoneInfo

from firebase_admin import auth as firebase_auth
from firebase_admin import firestore

from app.core.firestore import get_db, run_transaction
from app.services.settings_service import (
    DEFAULT_SETTINGS,
    get_settings,
    maintenance_info,
    save_maintenance,
)
from app.services.notification_service import deliver_to_user, notify_users, user_ids
from app.services.wallet_service import InsufficientFunds, apply, wallet_for


IST = ZoneInfo("Asia/Kolkata")
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
APP_BONUS_CAMPAIGN_PATTERN = re.compile(r"^[a-z0-9][a-z0-9_-]{2,39}$")
MAX_APP_BONUS_PER_USER = 10000


class AdminOperationError(ValueError):
    pass


class PlayerNotFound(AdminOperationError):
    pass


def search_players_for_removal(query: str, db: Any = None) -> list[dict[str, Any]]:
    database = db or get_db()
    query = " ".join(query.split())
    if not query or len(query) > 128 or "/" in query:
        raise AdminOperationError("Enter a valid email, account UID, or game name.")

    needle = query.casefold()
    candidates: dict[str, dict[str, Any]] = {}
    users = database.collection("users")
    for snapshot in users.stream():
        user = snapshot.to_dict() or {}
        identity_fields = (
            snapshot.id,
            user.get("email"),
            user.get("name"),
            user.get("ign"),
            user.get("gameUid"),
        )
        if any(
            isinstance(value, str) and needle in value.casefold()
            for value in identity_fields
        ):
            candidates[snapshot.id] = _removal_candidate(
                snapshot.id,
                user,
                database,
            )

    if query.isdigit() and 8 <= len(query) <= 12:
        claim = database.collection("gameUids").document(query).get()
        if claim.exists:
            uid = (claim.to_dict() or {}).get("uid")
            if isinstance(uid, str) and uid and uid not in candidates:
                snapshot = users.document(uid).get()
                if snapshot.exists:
                    candidates[uid] = _removal_candidate(
                        uid,
                        snapshot.to_dict() or {},
                        database,
                    )

    auth_user = None
    try:
        if EMAIL_PATTERN.fullmatch(query):
            auth_user = firebase_auth.get_user_by_email(query)
        elif "@" not in query and not candidates:
            auth_user = firebase_auth.get_user(query)
    except firebase_auth.UserNotFoundError:
        auth_user = None

    if auth_user is not None and auth_user.uid not in candidates:
        profile = users.document(auth_user.uid).get()
        candidates[auth_user.uid] = _removal_candidate(
            auth_user.uid,
            profile.to_dict() if profile.exists else {},
            database,
            auth_user=auth_user,
        )

    return sorted(
        candidates.values(),
        key=lambda item: (
            item["name"].casefold(),
            item["uid"],
        ),
    )[:25]


def remove_player_identity(
    uid: str,
    confirmed_uid: str,
    *,
    admin_uid: str = "local-admin",
    db: Any = None,
    storage_bucket: Any = None,
) -> dict[str, Any]:
    if not isinstance(uid, str) or not uid or "/" in uid or len(uid) > 128:
        raise AdminOperationError("Choose a valid player account.")
    if not isinstance(confirmed_uid, str) or confirmed_uid != uid:
        raise AdminOperationError("Type the player's account UID exactly to confirm.")

    database = db or get_db()
    user_ref = database.collection("users").document(uid)
    user_snapshot = user_ref.get()
    user = user_snapshot.to_dict() if user_snapshot.exists else {}
    user = user or {}

    auth_user = None
    try:
        auth_user = firebase_auth.get_user(uid)
    except firebase_auth.UserNotFoundError:
        pass
    if not user_snapshot.exists and auth_user is None:
        raise PlayerNotFound("Player account was not found.")
    if auth_user is not None and (auth_user.custom_claims or {}).get("admin") is True:
        raise AdminOperationError("Admin accounts cannot be removed here.")

    pending_withdrawals = [
        snapshot
        for snapshot in database.collection("withdrawals")
        .where("uid", "==", uid)
        .stream()
        if (snapshot.to_dict() or {}).get("status") == "pending"
    ]
    if pending_withdrawals:
        raise AdminOperationError(
            "Settle or reject pending withdrawals before removing this account."
        )

    if storage_bucket is None and user.get("upiShot") is True:
        raise AdminOperationError(
            "Configure the Firebase Storage bucket before removing this account's UPI screenshot."
        )
    screenshot = (
        storage_bucket.blob(f"users/{uid}/upi.jpg")
        if storage_bucket is not None and user.get("upiShot") is True
        else None
    )
    has_screenshot = screenshot.exists() if screenshot is not None else False

    if has_screenshot:
        screenshot.delete()
    if auth_user is not None:
        firebase_auth.delete_user(uid)

    game_uid_refs = [
        snapshot.reference
        for snapshot in database.collection("gameUids")
        .where("uid", "==", uid)
        .stream()
    ]

    notification_refs = [
        snapshot.reference
        for snapshot in database.collection("notifications")
        .where("uid", "==", uid)
        .stream()
    ]
    admin_notification_refs = [
        snapshot.reference
        for snapshot in database.collection("adminNotificationLogs")
        .where("uid", "==", uid)
        .stream()
    ]
    reward_refs = [
        snapshot.reference
        for snapshot in user_ref.collection("appUpdateRewards").stream()
    ]
    removal_refs = [
        *notification_refs,
        *admin_notification_refs,
        *reward_refs,
        database.collection("wallets").document(uid),
        database.collection("withdrawalLocks").document(uid),
    ]
    removal_refs.extend(game_uid_refs)

    audit_ref = database.collection("auditLogs").document()
    for offset in range(0, len(removal_refs), 450):
        batch = database.batch()
        for reference in removal_refs[offset : offset + 450]:
            batch.delete(reference)
        batch.commit()

    final_batch = database.batch()
    if user_snapshot.exists:
        final_batch.delete(user_ref)
    final_batch.set(
        audit_ref,
        {
            "uid": uid,
            "adminUid": admin_uid,
            "action": "player_identity_removed",
            "details": {
                "authAccountDeleted": auth_user is not None,
                "profileDeleted": user_snapshot.exists,
                "gameUidReleased": bool(game_uid_refs),
                "walletDeleted": True,
                "notificationsDeleted": len(notification_refs),
                "adminNotificationLogsDeleted": len(admin_notification_refs),
                "updateRewardClaimsDeleted": len(reward_refs),
                "upiScreenshotDeleted": has_screenshot,
                "financialAndTournamentHistoryRetained": True,
            },
            "createdAt": firestore.SERVER_TIMESTAMP,
        },
    )
    final_batch.commit()

    return {
        "uid": uid,
        "authAccountDeleted": auth_user is not None,
        "profileDeleted": user_snapshot.exists,
        "gameUidReleased": bool(game_uid_refs),
        "walletDeleted": True,
        "financialAndTournamentHistoryRetained": True,
    }


def revoke_app_update_bonuses(
    *,
    campaign_build_number: int = 2,
    admin_uid: str = "local-admin",
    db: Any = None,
) -> dict[str, int]:
    if (
        isinstance(campaign_build_number, bool)
        or not isinstance(campaign_build_number, int)
        or campaign_build_number < 1
    ):
        raise AdminOperationError("App reward campaign is invalid.")

    database = db or get_db()
    totals = {
        "accountsProcessed": 0,
        "accountsWithBalance": 0,
        "amountRemoved": 0,
        "amountUnavailable": 0,
    }
    users = database.collection("users").stream()
    for user_snapshot in users:
        uid = user_snapshot.id
        claim_ref = user_snapshot.reference.collection("appUpdateRewards").document(
            f"build_{campaign_build_number}"
        )
        wallet_ref = database.collection("wallets").document(uid)
        audit_ref = database.collection("auditLogs").document()

        def operation(tx: Any) -> dict[str, int]:
            claim_snapshot = claim_ref.get(transaction=tx)
            if not claim_snapshot.exists:
                return {"processed": 0, "removed": 0, "unavailable": 0}
            claim = claim_snapshot.to_dict() or {}
            if claim.get("revoked") is True:
                return {"processed": 0, "removed": 0, "unavailable": 0}

            wallet_snapshot = wallet_ref.get(transaction=tx)
            wallet = wallet_snapshot.to_dict() if wallet_snapshot.exists else {}
            bucket = claim.get("creditBucket")
            if bucket not in {"bonus", "deposited"}:
                bucket = "bonus"
            original_amount = claim.get("amount", 10)
            if (
                isinstance(original_amount, bool)
                or not isinstance(original_amount, int)
                or original_amount < 0
            ):
                raise AdminOperationError(
                    f"Reward claim for {uid} has an invalid amount."
                )
            reward_amount = min(original_amount, 10)
            balance = wallet.get(bucket, 0)
            if isinstance(balance, bool) or not isinstance(balance, int) or balance < 0:
                raise AdminOperationError(
                    f"Wallet balance for {uid} is invalid; reward removal stopped."
                )
            removed = min(balance, reward_amount)
            if removed:
                apply(
                    uid,
                    {
                        "deltas": {bucket: -removed},
                        "kind": "app_update_bonus_revoked",
                        "title": "App update reward removed",
                        "amt": removed,
                        "dir": "out",
                        "status": "paid",
                        "ref": f"apk-update-build-{campaign_build_number}",
                    },
                    tx,
                )

            unavailable = reward_amount - removed
            tx.update(
                claim_ref,
                {
                    "revoked": True,
                    "revokedAmount": removed,
                    "unavailableAmount": unavailable,
                    "revokedBucket": bucket,
                    "revokedBy": admin_uid,
                    "revokedAt": firestore.SERVER_TIMESTAMP,
                },
            )
            tx.create(
                audit_ref,
                {
                    "uid": uid,
                    "adminUid": admin_uid,
                    "action": "app_update_bonus_revoked",
                    "details": {
                        "campaignBuildNumber": campaign_build_number,
                        "bucket": bucket,
                        "amountRemoved": removed,
                        "amountUnavailable": unavailable,
                    },
                    "createdAt": firestore.SERVER_TIMESTAMP,
                },
            )
            return {"processed": 1, "removed": removed, "unavailable": unavailable}

        result = run_transaction(database, operation)
        totals["accountsProcessed"] += result["processed"]
        totals["accountsWithBalance"] += int(result["removed"] > 0)
        totals["amountRemoved"] += result["removed"]
        totals["amountUnavailable"] += result["unavailable"]

    return totals


def preview_app_bonus_distribution(
    campaign_id: str,
    amount: int,
    db: Any = None,
) -> dict[str, int | str]:
    campaign_id, amount = _validate_app_bonus_campaign(campaign_id, amount)
    database = db or get_db()
    accounts = list(database.collection("users").stream())
    already_credited = sum(
        1
        for account in accounts
        if account.reference.collection("appBonusCampaigns")
        .document(campaign_id)
        .get()
        .exists
    )
    account_count = len(accounts)
    eligible_count = account_count - already_credited
    return {
        "campaignId": campaign_id,
        "amountPerUser": amount,
        "accountCount": account_count,
        "alreadyCredited": already_credited,
        "eligibleCount": eligible_count,
        "estimatedTotal": eligible_count * amount,
    }


def distribute_app_bonus(
    campaign_id: str,
    amount: int,
    *,
    admin_uid: str = "local-admin",
    db: Any = None,
) -> dict[str, int | str]:
    campaign_id, amount = _validate_app_bonus_campaign(campaign_id, amount)
    database = db or get_db()
    totals: dict[str, int | str] = {
        "campaignId": campaign_id,
        "amountPerUser": amount,
        "accountsProcessed": 0,
        "accountsCredited": 0,
        "accountsAlreadyCredited": 0,
        "amountCredited": 0,
    }

    for account in database.collection("users").stream():
        uid = account.id
        claim_ref = account.reference.collection("appBonusCampaigns").document(
            campaign_id
        )
        audit_ref = database.collection("auditLogs").document()

        def operation(tx: Any) -> bool:
            claim_snapshot = claim_ref.get(transaction=tx)
            if claim_snapshot.exists:
                return False
            apply(
                uid,
                {
                    "deltas": {"deposited": amount},
                    "kind": "admin_app_bonus",
                    "title": "App bonus",
                    "amt": amount,
                    "dir": "in",
                    "status": "paid",
                    "ref": f"app-bonus-{campaign_id}",
                },
                tx,
            )
            tx.create(
                claim_ref,
                {
                    "campaignId": campaign_id,
                    "amount": amount,
                    "creditBucket": "deposited",
                    "adminUid": admin_uid,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                },
            )
            tx.create(
                audit_ref,
                {
                    "uid": uid,
                    "adminUid": admin_uid,
                    "action": "admin_app_bonus",
                    "details": {
                        "campaignId": campaign_id,
                        "amount": amount,
                        "bucket": "deposited",
                    },
                    "createdAt": firestore.SERVER_TIMESTAMP,
                },
            )
            return True

        credited = run_transaction(database, operation)
        totals["accountsProcessed"] += 1
        if credited:
            totals["accountsCredited"] += 1
            totals["amountCredited"] += amount
        else:
            totals["accountsAlreadyCredited"] += 1

    return totals


def _validate_app_bonus_campaign(campaign_id: str, amount: int) -> tuple[str, int]:
    if not isinstance(campaign_id, str):
        raise AdminOperationError(
            "Campaign ID must use 3-40 lowercase letters, numbers, dashes, or underscores."
        )
    campaign_id = campaign_id.strip().lower()
    if not APP_BONUS_CAMPAIGN_PATTERN.fullmatch(campaign_id):
        raise AdminOperationError(
            "Campaign ID must use 3-40 lowercase letters, numbers, dashes, or underscores."
        )
    if (
        isinstance(amount, bool)
        or not isinstance(amount, int)
        or not 1 <= amount <= MAX_APP_BONUS_PER_USER
    ):
        raise AdminOperationError(
            f"Bonus amount must be a whole number from ₹1 to ₹{MAX_APP_BONUS_PER_USER} per user."
        )
    return campaign_id, amount


def find_player(query: str, db: Any = None) -> dict[str, Any]:
    database = db or get_db()
    query = query.strip()
    if not query:
        raise PlayerNotFound("Enter a player UID.")

    uid = query
    if "/" in uid or len(uid) > 128:
        raise PlayerNotFound("Player not found.")
    if query.isdigit() and 8 <= len(query) <= 12:
        claim = database.collection("gameUids").document(query).get()
        if claim.exists:
            uid = (claim.to_dict() or {}).get("uid", "")
        else:
            raise PlayerNotFound("Player not found.")

    snapshot = database.collection("users").document(uid).get()
    if not snapshot.exists:
        raise PlayerNotFound("Player not found.")
    return _player_data(uid, snapshot.to_dict() or {}, database)


def list_holds(db: Any = None) -> list[dict[str, Any]]:
    database = db or get_db()
    users = database.collection("users")
    snapshots = {
        snapshot.id: snapshot
        for field in ("isHeld", "is_held")
        for snapshot in users.where(field, "==", True).stream()
    }
    return sorted(
        [
            {
                **_player_data(
                    snapshot.id,
                    snapshot.to_dict() or {},
                    database,
                ),
                "when": _format_time(
                    (snapshot.to_dict() or {}).get("heldAt")
                ),
                "reason": (snapshot.to_dict() or {}).get("holdReason", ""),
            }
            for snapshot in snapshots.values()
        ],
        key=lambda item: item["when"],
        reverse=True,
    )


def set_account_hold(
    uid: str,
    held: bool,
    *,
    reason: str = "",
    admin_uid: str = "local-admin",
    db: Any = None,
) -> None:
    if held:
        reason = " ".join(reason.split())
        if not 3 <= len(reason) <= 80:
            raise AdminOperationError("Reason must be 3-80 characters.")
    database = db or get_db()
    user_ref = database.collection("users").document(uid)
    audit_ref = database.collection("auditLogs").document()
    notification_ref = database.collection("notifications").document()
    notification_title = "Account security review"
    notification_body = (
        "We detected activity on your account that requires a security review. "
        "Your account has been temporarily placed on hold. Please contact "
        "support if you believe this is an error."
    )

    def operation(tx: Any) -> None:
        snapshot = user_ref.get(transaction=tx)
        if not snapshot.exists:
            raise PlayerNotFound("Player not found.")
        user = snapshot.to_dict() or {}
        currently_held = user.get("isHeld") is True or user.get("is_held") is True
        if currently_held == held:
            raise AdminOperationError(
                "Player is already on hold."
                if held
                else "Player is not on hold."
            )
        now_fields = {
            "isHeld": held,
            "is_held": held,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if held:
            now_fields.update(
                {
                    "holdReason": reason,
                    "heldAt": firestore.SERVER_TIMESTAMP,
                    "heldBy": admin_uid,
                }
            )
            tx.create(
                notification_ref,
                {
                    "uid": uid,
                    "title": notification_title,
                    "body": notification_body,
                    "link": "/profile",
                    "category": "account_hold",
                    "read": False,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                },
            )
        else:
            now_fields.update(
                {
                    "holdReason": firestore.DELETE_FIELD,
                    "heldAt": firestore.DELETE_FIELD,
                    "heldBy": firestore.DELETE_FIELD,
                }
            )
        tx.set(user_ref, now_fields, merge=True)
        tx.create(
            audit_ref,
            {
                "adminUid": admin_uid,
                "action": "account_hold" if held else "account_hold_release",
                "target": uid,
                "details": {"reason": reason} if held else {},
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )

    run_transaction(database, operation)
    if held:
        deliver_to_user(
            uid,
            notification_title,
            notification_body,
            "/profile",
            category="account_hold",
            admin_uid=admin_uid,
            notification_id=notification_ref.id,
            db=database,
        )


def credit_wallet(
    uid: str,
    amount: int,
    bucket: str,
    reason: str,
    *,
    admin_uid: str = "local-admin",
    db: Any = None,
) -> dict[str, Any]:
    if isinstance(amount, bool) or not isinstance(amount, int) or not 1 <= amount <= 10000:
        raise AdminOperationError("Amount must be between 1 and 10000 whole rupees.")
    if not isinstance(bucket, str) or bucket not in {"deposited", "winnings"}:
        raise AdminOperationError("Choose deposited or winnings.")
    if not isinstance(reason, str):
        raise AdminOperationError("Enter a reason for the adjustment.")
    reason = " ".join(reason.split())
    if not 3 <= len(reason) <= 80:
        raise AdminOperationError("Reason must be 3-80 characters.")

    database = db or get_db()
    user_ref = database.collection("users").document(uid)
    credit_ref = database.collection("adminWalletCredits").document()
    notification_ref = database.collection("notifications").document()
    audit_ref = database.collection("auditLogs").document()
    result: dict[str, Any] = {}

    def operation(tx: Any) -> None:
        user_snapshot = user_ref.get(transaction=tx)
        if not user_snapshot.exists:
            raise PlayerNotFound("Player not found.")
        wallet = apply(
            uid,
            {
                "deltas": {bucket: amount},
                "kind": "admin_credit",
                "title": "Wallet credited by support",
                "amt": amount,
                "dir": "in",
                "status": "paid",
                "ref": credit_ref.id,
            },
            tx,
        )
        tx.create(
            credit_ref,
            {
                "uid": uid,
                "amount": amount,
                "balance": bucket,
                "reason": reason,
                "adminUid": admin_uid,
                "transactionId": wallet["ledgerId"],
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        tx.create(
            notification_ref,
            {
                "uid": uid,
                "title": "Wallet updated",
                "body": (
                    "We apologize for the error. Your wallet has been updated "
                    f"with ₹{amount:,}."
                ),
                "link": "/wallet",
                "category": "wallet_credit",
                "read": False,
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        tx.create(
            audit_ref,
            {
                "adminUid": admin_uid,
                "action": "wallet_credit",
                "target": uid,
                "details": {
                    "amount": amount,
                    "bucket": bucket,
                    "reason": reason,
                    "transactionId": wallet["ledgerId"],
                },
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        result.update(wallet)

    run_transaction(database, operation)
    deliver_to_user(
        uid,
        "Wallet updated",
        f"We apologize for the error. Your wallet has been updated with ₹{amount:,}.",
        "/wallet",
        category="wallet_credit",
        admin_uid=admin_uid,
        notification_id=notification_ref.id,
        db=database,
    )
    return result


def list_wallet_credits(db: Any = None) -> list[dict[str, Any]]:
    database = db or get_db()
    credits = (
        database.collection("adminWalletCredits")
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .limit(50)
        .stream()
    )
    results = []
    for snapshot in credits:
        credit = snapshot.to_dict() or {}
        user_snapshot = database.collection("users").document(
            credit.get("uid", "")
        ).get()
        user = user_snapshot.to_dict() if user_snapshot.exists else {}
        results.append(
            {
                "when": _format_time(credit.get("createdAt")),
                "ign": (user or {}).get("ign", ""),
                "game_uid": (user or {}).get("gameUid", ""),
                "amount": credit.get("amount", 0),
                "balance": credit.get("balance", ""),
                "reason": credit.get("reason", ""),
            }
        )
    return results


def list_withdrawals(db: Any = None) -> list[dict[str, Any]]:
    database = db or get_db()
    records = (
        database.collection("withdrawals")
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .limit(200)
        .stream()
    )
    results = []
    for snapshot in records:
        withdrawal = snapshot.to_dict() or {}
        uid = withdrawal.get("uid", "")
        user_snapshot = database.collection("users").document(uid).get()
        user = user_snapshot.to_dict() if user_snapshot.exists else {}
        wallet = wallet_for(uid, database)
        settled_at = (
            withdrawal.get("paidAt")
            or withdrawal.get("rejectedAt")
            or withdrawal.get("updatedAt")
        )
        results.append(
            {
                "id": snapshot.id,
                "uid": uid,
                "amount": withdrawal.get("amount", 0),
                "upi": withdrawal.get("upi", ""),
                "upi_shot": bool((user or {}).get("upiShot", False)),
                "ign": (user or {}).get("ign", ""),
                "game_uid": (user or {}).get("gameUid", ""),
                "won": wallet["winnings"],
                "added": wallet["deposited"],
                "status": withdrawal.get("status", "pending"),
                "when": _format_time(withdrawal.get("createdAt")),
                "done": _format_time(settled_at) if settled_at else "",
                "ref": withdrawal.get("payoutRef", ""),
                "note": withdrawal.get("rejectReason", ""),
            }
        )
    return results


def tournament_result_rows(
    tournament_id: str,
    db: Any = None,
) -> tuple[dict[str, Any] | None, list[dict[str, Any]]]:
    database = db or get_db()
    tournament_snapshot = database.collection("tournaments").document(tournament_id).get()
    if not tournament_snapshot.exists:
        return None, []

    tournament = tournament_snapshot.to_dict() or {}
    entries = database.collection("tournamentEntries").where(
        "tournamentId", "==", tournament_id
    ).stream()
    saved_results = {
        (result.to_dict() or {}).get("uid"): result.to_dict() or {}
        for result in database.collection("tournamentResults")
        .where("tournamentId", "==", tournament_id)
        .stream()
    }
    rows = []
    for entry in entries:
        value = entry.to_dict() or {}
        uid = value.get("uid")
        if not isinstance(uid, str) or not uid:
            continue
        result = saved_results.get(uid, {})
        rows.append(
            {
                "uid": uid,
                "ign": value.get("ign", ""),
                "game_uid": value.get("gameUid", ""),
                "kills": result.get("kills", 0),
                "place": result.get("place", 0),
                "amount": result.get("amount", 0),
                "paid": result.get("status") == "approved",
            }
        )
    rows.sort(key=lambda row: (row["ign"].casefold(), row["uid"]))
    return tournament, rows


def save_tournament_results(
    tournament_id: str,
    rows: Any,
    db: Any = None,
) -> None:
    validated = _validate_result_rows(rows)
    database = db or get_db()
    tournament_ref = database.collection("tournaments").document(tournament_id)
    tournament_snapshot = tournament_ref.get()
    if not tournament_snapshot.exists:
        raise PlayerNotFound("Tournament was not found.")

    entries = {
        (snapshot.to_dict() or {}).get("uid")
        for snapshot in database.collection("tournamentEntries")
        .where("tournamentId", "==", tournament_id)
        .stream()
    }
    for row in validated:
        if row["uid"] not in entries:
            raise AdminOperationError("A result player did not join this tournament.")
        result_ref = _tournament_result_ref(database, tournament_id, row["uid"])

        def operation(tx: Any) -> None:
            existing = result_ref.get(transaction=tx)
            if existing.exists and (existing.to_dict() or {}).get("status") == "approved":
                raise AdminOperationError("An approved result cannot be changed.")
            tx.set(
                result_ref,
                {
                    **row,
                    "tournamentId": tournament_id,
                    "status": "draft",
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )

        run_transaction(database, operation)


def approve_tournament_results(
    tournament_id: str,
    rows: Any,
    *,
    admin_uid: str = "local-admin",
    db: Any = None,
) -> int:
    validated = _validate_result_rows(rows)
    database = db or get_db()
    approved = 0
    for row in validated:
        tournament_ref = database.collection("tournaments").document(tournament_id)
        entry_ref = _tournament_entry_ref(database, tournament_id, row["uid"])
        result_ref = _tournament_result_ref(database, tournament_id, row["uid"])
        user_ref = database.collection("users").document(row["uid"])

        def operation(tx: Any) -> None:
            tournament_snapshot = tournament_ref.get(transaction=tx)
            entry_snapshot = entry_ref.get(transaction=tx)
            result_snapshot = result_ref.get(transaction=tx)
            user_snapshot = user_ref.get(transaction=tx)
            if not tournament_snapshot.exists:
                raise PlayerNotFound("Tournament was not found.")
            if not entry_snapshot.exists:
                raise AdminOperationError("A result player did not join this tournament.")
            if not user_snapshot.exists:
                raise PlayerNotFound("Player not found.")
            if result_snapshot.exists and (result_snapshot.to_dict() or {}).get("status") == "approved":
                raise AdminOperationError("An approved result cannot be paid twice.")

            ledger_id = ""
            if row["amount"] > 0:
                wallet_result = apply(
                    row["uid"],
                    {
                        "deltas": {"winnings": row["amount"]},
                        "kind": "match_reward",
                        "title": "Tournament reward",
                        "amt": row["amount"],
                        "dir": "in",
                        "status": "paid",
                        "ref": result_ref.id,
                    },
                    tx,
                )
                ledger_id = wallet_result["ledgerId"]
            tx.set(
                result_ref,
                {
                    **row,
                    "uid": row["uid"],
                    "tournamentId": tournament_id,
                    "status": "approved",
                    "transactionId": ledger_id,
                    "approvedBy": admin_uid,
                    "approvedAt": firestore.SERVER_TIMESTAMP,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
                merge=True,
            )

        run_transaction(database, operation)
        approved += 1
    return approved


def profile_stats(uid: str, db: Any = None) -> dict[str, int]:
    database = db or get_db()
    matches = database.collection("tournamentEntries").where("uid", "==", uid).stream()
    results = database.collection("tournamentResults").where("uid", "==", uid).stream()
    match_count = sum(1 for _ in matches)
    approved_results = [
        snapshot.to_dict() or {}
        for snapshot in results
        if (snapshot.to_dict() or {}).get("status") == "approved"
    ]
    return {
        "matches": match_count,
        "wins": sum(1 for result in approved_results if result.get("amount", 0) > 0),
        "kills": sum(_whole_number(result.get("kills", 0)) for result in approved_results),
        "earned": sum(_whole_number(result.get("amount", 0)) for result in approved_results),
    }


def player_account_details(uid: str, db: Any = None) -> dict[str, Any]:
    database = db or get_db()
    user_snapshot = database.collection("users").document(uid).get()
    if not user_snapshot.exists:
        raise PlayerNotFound("Player not found.")
    user = user_snapshot.to_dict() or {}
    transactions = (
        database.collection("transactions")
        .where("uid", "==", uid)
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .stream()
    )
    history = []
    for snapshot in transactions:
        entry = snapshot.to_dict() or {}
        history.append(
            {
                "id": snapshot.id,
                "kind": entry.get("kind", ""),
                "title": entry.get("title", ""),
                "amount": _whole_number(entry.get("amt", 0)),
                "direction": entry.get("dir", ""),
                "status": entry.get("status", ""),
                "reference": entry.get("ref", ""),
                "date": _format_time(entry.get("createdAt")),
            }
        )
    return {
        "uid": uid,
        "name": user.get("name", "Player"),
        "email": user.get("email", ""),
        "ign": user.get("ign", ""),
        "game_uid": user.get("gameUid", ""),
        "held": user.get("isHeld") is True or user.get("is_held") is True,
        "wallet": wallet_for(uid, database),
        "stats": profile_stats(uid, database),
        "transactions": history,
    }


def deduct_wallet(
    uid: str,
    amount: int,
    bucket: str,
    reason: str,
    *,
    admin_uid: str = "local-admin",
    db: Any = None,
) -> dict[str, Any]:
    if isinstance(amount, bool) or not isinstance(amount, int) or amount < 1:
        raise AdminOperationError("Amount must be at least 1 whole rupee.")
    if not isinstance(bucket, str) or bucket not in {"deposited", "winnings"}:
        raise AdminOperationError("Choose deposited or winnings.")
    if not isinstance(reason, str):
        raise AdminOperationError("Enter a reason for the adjustment.")
    reason = " ".join(reason.split())
    if not 3 <= len(reason) <= 120:
        raise AdminOperationError("Reason must be 3-120 characters.")

    database = db or get_db()
    user_ref = database.collection("users").document(uid)
    notification_ref = database.collection("notifications").document()
    audit_ref = database.collection("auditLogs").document()
    bucket_label = "deposited balance" if bucket == "deposited" else "winnings"
    title = "Wallet adjustment"
    body = (
        f"₹{amount:,} was deducted from your {bucket_label} after a "
        "suspicious-amount review. If you have any questions, please contact "
        "support."
    )
    result: dict[str, Any] = {}

    def operation(tx: Any) -> None:
        user_snapshot = user_ref.get(transaction=tx)
        if not user_snapshot.exists:
            raise PlayerNotFound("Player not found.")
        wallet = apply(
            uid,
            {
                "deltas": {bucket: -amount},
                "kind": "admin_deduction",
                "title": "Suspicious amount adjustment",
                "amt": amount,
                "dir": "out",
                "status": "paid",
                "ref": audit_ref.id,
            },
            tx,
        )
        tx.create(
            notification_ref,
            {
                "uid": uid,
                "title": title,
                "body": body,
                "link": "/wallet",
                "category": "wallet_adjustment",
                "read": False,
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        tx.create(
            audit_ref,
            {
                "adminUid": admin_uid,
                "action": "wallet_deduction",
                "target": uid,
                "details": {
                    "amount": amount,
                    "bucket": bucket,
                    "reason": reason,
                    "transactionId": wallet["ledgerId"],
                },
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        result.update(wallet)

    try:
        run_transaction(database, operation)
    except InsufficientFunds as exception:
        raise AdminOperationError("Amount exceeds the selected wallet balance.") from exception

    result["notificationStatus"] = deliver_to_user(
        uid,
        title,
        body,
        "/wallet",
        category="wallet_adjustment",
        admin_uid=admin_uid,
        notification_id=notification_ref.id,
        db=database,
    )
    return result


def _validate_result_rows(rows: Any) -> list[dict[str, Any]]:
    if not isinstance(rows, list) or not rows:
        raise AdminOperationError("Add at least one player result.")
    validated = []
    seen = set()
    for row in rows:
        if not isinstance(row, dict):
            raise AdminOperationError("A player result is invalid.")
        uid = row.get("uid")
        if not isinstance(uid, str) or not uid.strip() or len(uid) > 128:
            raise AdminOperationError("A player result is missing its account.")
        uid = uid.strip()
        if uid in seen:
            raise AdminOperationError("A player can only appear once per result.")
        seen.add(uid)
        numbers = {}
        for field, maximum in (("kills", 99), ("place", 20), ("amount", 1_000_000)):
            value = row.get(field)
            if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= maximum:
                raise AdminOperationError(f"{field.capitalize()} must be a whole number in range.")
            numbers[field] = value
        validated.append({"uid": uid, **numbers})
    return validated


def _whole_number(value: Any) -> int:
    if isinstance(value, int) and not isinstance(value, bool) and value > 0:
        return value
    return 0


def _tournament_result_ref(database: Any, tournament_id: str, uid: str) -> Any:
    import hashlib

    identifier = hashlib.sha256(f"{tournament_id}:{uid}".encode("utf-8")).hexdigest()
    return database.collection("tournamentResults").document(identifier)


def _tournament_entry_ref(database: Any, tournament_id: str, uid: str) -> Any:
    entries = database.collection("tournamentEntries").where(
        "tournamentId", "==", tournament_id
    ).stream()
    entry = next(
        (
            snapshot
            for snapshot in entries
            if (snapshot.to_dict() or {}).get("uid") == uid
        ),
        None,
    )
    if entry is None:
        return database.collection("tournamentEntries").document(
            f"{tournament_id}_{uid}"
        )
    return entry.reference


def settle_withdrawal(
    withdrawal_id: str,
    status: str,
    *,
    ref: str = "",
    reason: str = "",
    admin_uid: str = "local-admin",
    db: Any = None,
) -> dict[str, Any]:
    if status not in {"paid", "rejected"}:
        raise AdminOperationError("Choose paid or rejected.")
    ref = " ".join(ref.split())
    reason = " ".join(reason.split())
    if len(ref) > 80:
        raise AdminOperationError("UPI reference must be 80 characters or fewer.")
    if len(reason) > 120:
        raise AdminOperationError("Rejection reason must be 120 characters or fewer.")

    database = db or get_db()
    withdrawal_ref = database.collection("withdrawals").document(withdrawal_id)
    notification_ref = database.collection("notifications").document()
    audit_ref = database.collection("auditLogs").document()
    result: dict[str, Any] = {}

    def operation(tx: Any) -> None:
        snapshot = withdrawal_ref.get(transaction=tx)
        if not snapshot.exists:
            raise PlayerNotFound("Withdrawal request was not found.")
        withdrawal = snapshot.to_dict() or {}
        if withdrawal.get("status") != "pending":
            raise AdminOperationError("This withdrawal request is already settled.")
        uid = withdrawal.get("uid")
        amount = withdrawal.get("amount")
        if not isinstance(uid, str) or not uid:
            raise AdminOperationError("Withdrawal request has no player account.")
        if isinstance(amount, bool) or not isinstance(amount, int) or amount < 1:
            raise AdminOperationError("Withdrawal amount is invalid.")

        user_ref = database.collection("users").document(uid)
        user_snapshot = user_ref.get(transaction=tx)
        if not user_snapshot.exists:
            raise PlayerNotFound("Player not found.")

        transaction_id = withdrawal.get("transactionId")
        if isinstance(transaction_id, str) and transaction_id:
            ledger_ref = database.collection("transactions").document(transaction_id)
            ledger_snapshot = ledger_ref.get(transaction=tx)
            if not ledger_snapshot.exists:
                raise AdminOperationError("Withdrawal ledger entry was not found.")
            ledger = ledger_snapshot.to_dict() or {}
        else:
            ledger_query = (
                database.collection("transactions")
                .where("uid", "==", uid)
                .where("ref", "==", withdrawal_id)
            )
            ledger_snapshots = list(tx.get(ledger_query))
            matching = next(
                (
                    item
                    for item in ledger_snapshots
                    if (item.to_dict() or {}).get("kind") == "withdraw"
                    and (item.to_dict() or {}).get("status") == "pending"
                ),
                None,
            )
            if matching is None:
                raise AdminOperationError("Withdrawal ledger entry was not found.")
            ledger_ref = matching.reference
            ledger = matching.to_dict() or {}
            transaction_id = matching.id

        if ledger.get("kind") != "withdraw" or ledger.get("status") != "pending":
            raise AdminOperationError("Withdrawal ledger entry is already settled.")

        if status == "rejected":
            refund = apply(
                uid,
                {
                    "deltas": {"winnings": amount},
                    "kind": "withdraw_refund",
                    "title": "Withdrawal rejected — amount returned",
                    "amt": amount,
                    "dir": "in",
                    "status": "paid",
                    "ref": withdrawal_id,
                },
                tx,
            )
            result["refundTransactionId"] = refund["ledgerId"]

        settled_at = firestore.SERVER_TIMESTAMP
        withdrawal_updates = {
            "status": status,
            "updatedAt": settled_at,
            "transactionId": transaction_id,
        }
        if status == "paid":
            withdrawal_updates.update({"paidAt": settled_at, "payoutRef": ref})
            title = "Withdrawal successful"
            body = f"Your withdrawal of ₹{amount:,} has been paid to your UPI ID."
            category = "withdrawal_paid"
        else:
            withdrawal_updates.update(
                {
                    "rejectedAt": settled_at,
                    "rejectReason": reason,
                    "refundTransactionId": result["refundTransactionId"],
                }
            )
            title = "Withdrawal request update"
            body = (
                f"Your withdrawal request for ₹{amount:,} was rejected. "
                "The amount has been returned to your winnings."
            )
            category = "withdrawal_rejected"

        tx.update(withdrawal_ref, withdrawal_updates)
        tx.update(ledger_ref, {"status": status})
        tx.create(
            notification_ref,
            {
                "uid": uid,
                "title": title,
                "body": body,
                "link": "/wallet",
                "category": category,
                "read": False,
                "createdAt": settled_at,
            },
        )
        tx.create(
            audit_ref,
            {
                "adminUid": admin_uid,
                "action": f"withdrawal_{status}",
                "target": withdrawal_id,
                "details": {
                    "uid": uid,
                    "amount": amount,
                    "transactionId": transaction_id,
                    "ref": ref if status == "paid" else "",
                    "reason": reason if status == "rejected" else "",
                    "refundTransactionId": result.get("refundTransactionId", ""),
                },
                "createdAt": settled_at,
            },
        )
        result.update(
            {
                "uid": uid,
                "amount": amount,
                "status": status,
                "title": title,
                "body": body,
                "category": category,
                "notificationId": notification_ref.id,
            }
        )

    run_transaction(database, operation)
    notification_status = deliver_to_user(
        result["uid"],
        result["title"],
        result["body"],
        "/wallet",
        category=result["category"],
        admin_uid=admin_uid,
        notification_id=result["notificationId"],
        db=database,
    )
    result["notificationStatus"] = notification_status
    return result


def delete_settled_withdrawal(
    withdrawal_id: str,
    *,
    db: Any = None,
) -> None:
    database = db or get_db()
    withdrawal_ref = database.collection("withdrawals").document(withdrawal_id)

    def operation(tx: Any) -> None:
        snapshot = withdrawal_ref.get(transaction=tx)
        if not snapshot.exists:
            raise PlayerNotFound("Withdrawal request was not found.")
        if (snapshot.to_dict() or {}).get("status") not in {"paid", "rejected"}:
            raise AdminOperationError("Pending withdrawals cannot be deleted.")
        tx.delete(withdrawal_ref)

    run_transaction(database, operation)


def clear_settled_withdrawals(db: Any = None) -> int:
    database = db or get_db()
    records = list(database.collection("withdrawals").stream())
    settled = [
        snapshot
        for snapshot in records
        if (snapshot.to_dict() or {}).get("status") in {"paid", "rejected"}
    ]
    for offset in range(0, len(settled), 450):
        batch = database.batch()
        for snapshot in settled[offset : offset + 450]:
            batch.delete(snapshot.reference)
        batch.commit()
    return len(settled)


def update_maintenance(
    enabled: bool,
    message: str,
    eta: str,
    *,
    admin_uid: str = "local-admin",
    db: Any = None,
) -> dict[str, Any]:
    if not isinstance(enabled, bool):
        raise AdminOperationError("Maintenance status must be enabled or disabled.")
    message = " ".join(message.split())
    eta = " ".join(eta.split())
    if len(message) > 200:
        raise AdminOperationError("Maintenance message must be 200 characters or fewer.")
    if len(eta) > 40:
        raise AdminOperationError("Maintenance ETA must be 40 characters or fewer.")
    previous = get_settings(db)
    result = save_maintenance(
        enabled,
        message or "We will be back shortly.",
        eta,
        updated_by=admin_uid,
        db=db,
    )
    notification_counts = None
    if enabled and previous.get("maintenance") is not True:
        maintenance_body = (
            "RIVALON is temporarily under maintenance. Our team is working to "
            "restore service as soon as possible. Please check back shortly."
        )
        if eta:
            maintenance_body += f" We currently expect service to return: {eta}."
        notification_counts = notify_users(
            user_ids(db),
            "RIVALON is under maintenance",
            maintenance_body,
            "/",
            category="maintenance",
            admin_uid=admin_uid,
            db=db,
        )
    database = db or get_db()
    audit_ref = database.collection("auditLogs").document()
    audit_ref.set(
        {
            "adminUid": admin_uid,
            "action": "maintenance_update",
            "target": "settings/app",
            "details": {
                **result,
                "notificationCounts": notification_counts,
            },
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
    )
    return {
        **result,
        "notificationCounts": notification_counts,
    }


def get_maintenance(db: Any = None) -> dict[str, Any]:
    database = db or get_db()
    snapshot = database.collection("settings").document("app").get()
    settings = snapshot.to_dict() if snapshot.exists else {}
    merged = {**DEFAULT_SETTINGS, **(settings or {})}
    return maintenance_info(merged)


def _player_data(
    uid: str,
    user: dict[str, Any],
    database: Any,
) -> dict[str, Any]:
    wallet = wallet_for(uid, database)
    return {
        "uid": uid,
        "ign": user.get("ign", ""),
        "game_uid": user.get("gameUid", ""),
        "name": user.get("name", "Player"),
        "held": user.get("isHeld") is True or user.get("is_held") is True,
        "total": wallet["total"],
        "deposited": wallet["deposited"],
        "winnings": wallet["winnings"],
        "bonus": wallet["bonus"],
    }


def _removal_candidate(
    uid: str,
    user: dict[str, Any],
    database: Any,
    *,
    auth_user: Any = None,
) -> dict[str, Any]:
    wallet = wallet_for(uid, database)
    name = _first_text(
        user.get("name"),
        getattr(auth_user, "display_name", ""),
        user.get("ign"),
    )
    email = _first_text(user.get("email"), getattr(auth_user, "email", ""))
    ign = _first_text(user.get("ign"))
    return {
        "uid": uid,
        "name": name or "Player",
        "email": email,
        "ign": ign,
        "game_uid": _first_text(user.get("gameUid")),
        "profile_exists": bool(user),
        "deposited": wallet["deposited"],
        "bonus": wallet["bonus"],
        "winnings": wallet["winnings"],
        "total": wallet["total"],
    }


def _first_text(*values: Any) -> str:
    return next(
        (
            value.strip()
            for value in values
            if isinstance(value, str) and value.strip()
        ),
        "",
    )


def _format_time(value: Any) -> str:
    if not isinstance(value, datetime):
        return "—"
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(IST).strftime("%d %b, %I:%M %p")
