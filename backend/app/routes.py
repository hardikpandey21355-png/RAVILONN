import hashlib
import re
from datetime import datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo

from firebase_admin import firestore
from flask import Blueprint, current_app, g, jsonify, render_template, request

from app.core.auth import (
    api_error,
    bearer_token,
    held_error,
    require_auth,
    verified_claims,
)
from app.core.firestore import get_db, get_storage_bucket, run_transaction
from app.services.settings_service import (
    LATEST_APP_BUILD_NUMBER,
    get_add_money_method,
    get_settings,
    maintenance_info,
)
from app.services.admin_service import profile_stats
from app.services.tranzupi_service import (
    TranzUPIError,
    check_payment_order,
    create_payment_order,
)
from app.services.tournament_service import (
    AlreadyJoined,
    MissingGameId,
    SlotAlreadyTaken,
    TournamentJoinError,
    TournamentNotJoinable,
    joined_matches,
    join_tournament,
    joined_tournament_slots,
    list_tournaments,
    slots_for_tournament,
)
from app.services.user_service import AccountOnHold, get_or_create_user
from app.services.wallet_service import (
    InsufficientFunds,
    apply,
    claim_app_update_bonus,
    wallet_for,
)


api = Blueprint("api", __name__)
IST = ZoneInfo("Asia/Kolkata")
UPI_PATTERN = re.compile(r"^[\w.\-]{2,}@[A-Za-z]{2,}$")
UTR_PATTERN = re.compile(r"^[A-Za-z0-9]{6,30}$")
GAME_UID_PATTERN = re.compile(r"^\d{8,12}$")
SHOT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
}


@api.get("/pay/return")
def payment_return() -> Any:
    order_id = (
        request.args.get("order_id")
        or request.args.get("orderId")
        or request.args.get("id")
        or ""
    ).strip()
    status = "failed"
    if order_id and len(order_id) <= 100:
        try:
            result = check_payment_order(order_id)
            provider_status = result.get("status")
            if provider_status in {"paid", "pending"}:
                status = provider_status
            elif provider_status == "failed":
                status = "failed"
        except TranzUPIError as exception:
            if "not found" not in str(exception).lower():
                status = "pending"
    return render_template("payment_return.html", status=status)


@api.post("/api/auth/login")
def login() -> tuple[Any, int]:
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return api_error("Request body must be valid JSON.", 400)
    body_token = body.get("idToken")
    if not isinstance(body_token, str) or not body_token.strip():
        return api_error("Firebase ID token is required.", 400)
    token, error = bearer_token()
    if error:
        return error
    if token != body_token:
        return api_error("Authorization token does not match idToken.", 401)
    claims, error = verified_claims(token or "")
    if error:
        return error
    try:
        user = get_or_create_user(claims or {})
    except AccountOnHold:
        return held_error()
    return jsonify(_session_response(user, user.get("uid", ""))), 200


@api.get("/api/me")
@require_auth
def me() -> tuple[Any, int]:
    db = get_db()
    snapshot = db.collection("users").document(g.uid).get()
    if not snapshot.exists:
        return api_error("User session was not found. Please sign in again.", 401)
    user = snapshot.to_dict() or {}
    if _is_held(user):
        return held_error()
    return jsonify(_session_response(user, g.uid)), 200


@api.get("/api/profile/stats")
@require_auth
def get_profile_stats() -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    if _is_held(user or {}):
        return held_error()
    return jsonify({"ok": True, **profile_stats(g.uid)}), 200


@api.get("/api/matches")
@require_auth
def get_matches() -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    if _is_held(user or {}):
        return held_error()
    return jsonify({"ok": True, "matches": joined_matches(g.uid)}), 200


@api.get("/api/tournaments")
@require_auth
def get_tournaments() -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    if _is_held(user or {}):
        return held_error()
    my_slots = joined_tournament_slots(g.uid)
    tournaments = []
    for item in list_tournaments():
        if item.get("isDeleting") is True or item.get("status") not in {
            "live",
            "upcoming",
        }:
            continue
        item.pop("_startAt", None)
        joined_by_me = item["id"] in my_slots
        item["joinedByMe"] = joined_by_me
        item["mySlot"] = my_slots.get(item["id"])
        if not joined_by_me:
            for field in ("roomId", "roomPass", "room_id", "room_pass"):
                item.pop(field, None)
        start_at = item.get("startAt")
        if isinstance(start_at, datetime):
            item["startAt"] = start_at.isoformat()
        tournaments.append(item)
    settings = get_settings()
    return jsonify(
        {
            "ok": True,
            "tournaments": tournaments,
            "wallet": wallet_for(g.uid),
            "maintenance": maintenance_info(settings),
        }
    ), 200


@api.get("/api/app-status")
@require_auth
def app_status() -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    if _is_held(user or {}):
        return held_error()
    return jsonify(
        {"ok": True, "maintenance": maintenance_info(get_settings())}
    ), 200


@api.get("/api/app-update")
@require_auth
def app_update_info() -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    if _is_held(user or {}):
        return held_error()

    settings = get_settings()
    version_code = settings["appLatestVersionCode"]
    if isinstance(version_code, bool) or not isinstance(version_code, int):
        version_code = LATEST_APP_BUILD_NUMBER
    else:
        version_code = max(version_code, LATEST_APP_BUILD_NUMBER)
    version_name = settings["appLatestVersionName"]
    if not isinstance(version_name, str):
        version_name = "1.1.0"
    download_url = settings["appDownloadUrl"]
    if not isinstance(download_url, str):
        download_url = ""
    message = "App use karte rehne ke liye latest update install karein."

    return jsonify(
        {
            "ok": True,
            "enabled": True,
            "forceUpdate": True,
            "latestBuildNumber": version_code,
            "latestVersionName": version_name,
            "downloadUrl": download_url,
            "message": message,
        }
    ), 200


@api.post("/api/app-update/claim")
@require_auth
def claim_app_update_reward() -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    if _is_held(user or {}):
        return held_error()

    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return api_error("Request body must be valid JSON.", 400)
    build_number = body.get("buildNumber")
    if isinstance(build_number, bool) or not isinstance(build_number, int):
        return api_error("App build number must be an integer.", 400)

    settings = get_settings()
    campaign_build = settings.get("appBonusBuildNumber", 2)
    if isinstance(campaign_build, bool) or not isinstance(campaign_build, int):
        campaign_build = 2
    try:
        credited = claim_app_update_bonus(
            g.uid,
            build_number,
            campaign_build_number=campaign_build,
            enabled=False,
        )
    except AccountOnHold:
        return held_error()

    return jsonify(
        {
            "ok": True,
            "credited": credited,
            "amount": 10 if credited else 0,
            "wallet": wallet_for(g.uid),
        }
    ), 200


@api.get("/api/tournaments/<tournament_id>/slots")
@require_auth
def get_tournament_slots(tournament_id: str) -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    if _is_held(user or {}):
        return held_error()
    try:
        slots = slots_for_tournament(tournament_id, g.uid)
    except TournamentNotJoinable as exception:
        return api_error(str(exception), 404)
    return jsonify({"ok": True, **slots}), 200


@api.post("/api/tournaments/<tournament_id>/join")
@require_auth
def join_tournament_route(tournament_id: str) -> tuple[Any, int]:
    body, error = _json_body()
    if error:
        return error
    try:
        result = join_tournament(g.uid, tournament_id, body.get("slot"))
    except AccountOnHold:
        return held_error()
    except MissingGameId:
        return api_error("Save your game ID before joining.", 400)
    except AlreadyJoined as exception:
        return api_error(str(exception), 409)
    except SlotAlreadyTaken as exception:
        return api_error(str(exception), 409)
    except InsufficientFunds:
        return api_error("Insufficient wallet balance.", 400)
    except TournamentJoinError as exception:
        return api_error(str(exception), 400)
    wallet = {
        key: value
        for key, value in result["wallet"].items()
        if key != "ledgerId"
    }
    return jsonify(
        {
            "ok": True,
            "slot": result["slot"],
            "wallet": wallet,
            "joined": True,
        }
    ), 201


@api.get("/api/wallet")
@require_auth
def get_wallet() -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    db = get_db()
    settings = get_settings(db)
    wallet = wallet_for(g.uid, db)
    return jsonify(
        {
            "ok": True,
            "wallet": wallet,
            "upi": user.get("upi", ""),
            "hasUpi": bool(user.get("upi")),
            "dailyLeft": _daily_left(db, g.uid, settings),
            "limits": _public_limits(settings),
            "paymentMethod": get_add_money_method(settings),
        }
    ), 200


@api.get("/api/wallet/transactions")
@require_auth
def get_transactions() -> tuple[Any, int]:
    db = get_db()
    kind = request.args.get("kind", "").strip()
    limit_value = request.args.get("limit", "50")
    try:
        limit = int(limit_value)
    except (TypeError, ValueError):
        return api_error("limit must be an integer between 1 and 100.", 400)
    if not 1 <= limit <= 100:
        return api_error("limit must be an integer between 1 and 100.", 400)

    query = db.collection("transactions").where("uid", "==", g.uid)
    if kind:
        query = query.where("kind", "==", kind)
    query = query.order_by("createdAt", direction=firestore.Query.DESCENDING).limit(limit)
    now = datetime.now(timezone.utc)
    items = []
    for snapshot in query.stream():
        entry = snapshot.to_dict() or {}
        created_at = entry.get("createdAt")
        wait_left = None
        if entry.get("kind") == "added" and entry.get("status") == "pending":
            if isinstance(created_at, datetime):
                if created_at.tzinfo is None:
                    created_at = created_at.replace(tzinfo=timezone.utc)
                wait_left = max(0, 4 * 60 * 60 - int((now - created_at).total_seconds()))
            else:
                wait_left = 4 * 60 * 60
        items.append(
            {
                "id": snapshot.id,
                "kind": entry.get("kind", ""),
                "title": entry.get("title", ""),
                "date": _format_date(created_at),
                "amt": _format_rupees(entry.get("amt", 0)),
                "dir": entry.get("dir", ""),
                "status": entry.get("status", ""),
                "waitLeft": wait_left,
            }
        )
    return jsonify({"ok": True, "transactions": items}), 200


@api.post("/api/wallet/deposit-request")
@require_auth
def deposit_request() -> tuple[Any, int]:
    settings = get_settings()
    if get_add_money_method(settings) != "manual":
        message = (
            "Adding money is currently disabled."
            if get_add_money_method(settings) == "off"
            else "Manual payments are not available yet."
        )
        return api_error(message, 503)
    body, error = _json_body()
    if error:
        return error
    amount, error = _amount(body.get("amount"))
    if error:
        return error
    utr = body.get("utr")
    if not isinstance(utr, str) or not UTR_PATTERN.fullmatch(utr.strip()):
        return api_error("UTR must be 6-30 alphanumeric characters.", 400)
    utr = utr.strip().upper()
    db = get_db()
    if not settings["minAdd"] <= amount <= settings["maxAdd"]:
        return api_error(
            f"Deposit amount must be between {settings['minAdd']} and {settings['maxAdd']} rupees.",
            400,
        )
    user_ref = db.collection("users").document(g.uid)
    wallet_ref = db.collection("wallets").document(g.uid)
    deposit_ref = db.collection("deposits").document(hashlib.sha256(utr.encode()).hexdigest())
    ledger_ref = db.collection("transactions").document()

    def operation(tx: Any) -> dict[str, Any]:
        user_snapshot = user_ref.get(transaction=tx)
        if not user_snapshot.exists:
            raise UserNotFound
        if _is_held(user_snapshot.to_dict() or {}):
            raise AccountOnHold
        if deposit_ref.get(transaction=tx).exists:
            raise DuplicateUtr
        wallet_snapshot = wallet_ref.get(transaction=tx)
        wallet = wallet_snapshot.to_dict() if wallet_snapshot.exists else {}
        balance = sum(_wallet_bucket(wallet, key) for key in ("deposited", "winnings", "bonus"))
        tx.create(
            deposit_ref,
            {
                "uid": g.uid,
                "utr": utr,
                "amount": amount,
                "status": "pending",
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        tx.create(
            ledger_ref,
            {
                "uid": g.uid,
                "kind": "added",
                "title": "Deposit request",
                "amt": amount,
                "dir": "in",
                "status": "pending",
                "ref": deposit_ref.id,
                "balanceAfter": balance,
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        return {"id": ledger_ref.id, "balance": balance}

    try:
        result = run_transaction(db, operation)
    except AccountOnHold:
        return held_error()
    except UserNotFound:
        return api_error("User profile was not found. Please sign in again.", 401)
    except DuplicateUtr:
        return api_error("This UTR has already been submitted.", 409)
    wallet = wallet_for(g.uid, db)
    tx_snapshot = db.collection("transactions").document(result["id"]).get()
    tx_data = tx_snapshot.to_dict() or {}
    return jsonify(
        {
            "ok": True,
            "tx": _transaction_item(result["id"], tx_data),
            "wallet": wallet,
        }
    ), 201


@api.post("/api/wallet/payment-orders")
@require_auth
def wallet_payment_order() -> tuple[Any, int]:
    body, error = _json_body()
    if error:
        return error
    amount, error = _amount(body.get("amount"))
    if error:
        return error
    db = get_db()
    user, error = _require_user()
    if error:
        return error
    if _is_held(user or {}):
        return held_error()
    settings = get_settings(db)
    if get_add_money_method(settings) != "gateway":
        message = (
            "Adding money is currently disabled."
            if get_add_money_method(settings) == "off"
            else "Manual payments are not available yet."
        )
        return api_error(message, 503)
    if not settings["minAdd"] <= amount <= settings["maxAdd"]:
        return api_error(
            f"Deposit amount must be between {settings['minAdd']} and "
            f"{settings['maxAdd']} rupees.",
            400,
        )
    mobile = body.get("customer_mobile", "")
    if not isinstance(mobile, str):
        return api_error("Enter a valid mobile number.", 400)
    try:
        order = create_payment_order(
            g.uid,
            amount,
            customer_mobile=mobile.strip(),
            db=db,
        )
    except TranzUPIError as exception:
        return api_error(str(exception), 503)
    return jsonify({"ok": True, **order}), 201


@api.get("/api/wallet/payment-orders/<order_id>")
@require_auth
def wallet_payment_status(order_id: str) -> tuple[Any, int]:
    try:
        result = check_payment_order(order_id, uid=g.uid)
    except TranzUPIError as exception:
        status = 404 if "not found" in str(exception).lower() else 502
        return api_error(str(exception), status)
    ledger = result.pop("ledger", None)
    if isinstance(ledger, dict):
        ledger_id = ledger.pop("id", "")
        result["tx"] = _transaction_item(ledger_id, ledger)
    return jsonify({"ok": True, **result}), 200


@api.post("/api/payments/tranzupi/webhook")
def tranzupi_webhook() -> tuple[Any, int]:
    order_id = request.form.get("order_id", "").strip()
    if not order_id:
        return jsonify({"ok": False, "error": "order_id is required."}), 400
    try:
        check_payment_order(order_id)
    except TranzUPIError as exception:
        current_app.logger.warning(
            "TranzUPI webhook verification failed (%s).",
            type(exception).__name__,
        )
        return jsonify({"ok": False, "error": "Payment verification is unavailable."}), 503
    return jsonify({"ok": True}), 200


@api.post("/api/wallet/withdraw")
@require_auth
def withdraw() -> tuple[Any, int]:
    body, error = _json_body()
    if error:
        return error
    amount, error = _amount(body.get("amount"))
    if error:
        return error
    db = get_db()
    settings = get_settings(db)
    if amount < settings["minWithdraw"]:
        return api_error(f"Minimum withdrawal is {settings['minWithdraw']} rupees.", 400)
    day_key = datetime.now(IST).strftime("%Y-%m-%d")
    user_ref = db.collection("users").document(g.uid)
    wallet_ref = db.collection("wallets").document(g.uid)
    lock_ref = db.collection("withdrawalLocks").document(g.uid)
    withdrawal_ref = db.collection("withdrawals").document()
    ledger_id_holder: dict[str, str] = {}

    def operation(tx: Any) -> dict[str, Any]:
        user_snapshot = user_ref.get(transaction=tx)
        if not user_snapshot.exists:
            raise UserNotFound
        user = user_snapshot.to_dict() or {}
        if _is_held(user):
            raise AccountOnHold
        upi = user.get("upi", "")
        if not isinstance(upi, str) or not upi:
            raise MissingUpi

        lock_snapshot = lock_ref.get(transaction=tx)
        if lock_snapshot.exists:
            lock_data = lock_snapshot.to_dict() or {}
            pending_id = lock_data.get("withdrawalId")
            pending_snapshot = (
                db.collection("withdrawals").document(pending_id).get(transaction=tx)
                if isinstance(pending_id, str)
                else None
            )
            if pending_snapshot is not None and pending_snapshot.exists:
                if (pending_snapshot.to_dict() or {}).get("status") == "pending":
                    raise WithdrawalPending

        daily_query = (
            db.collection("withdrawals")
            .where("uid", "==", g.uid)
            .where("dayKey", "==", day_key)
        )
        daily_docs = list(tx.get(daily_query))
        already_withdrawn = sum(
            _wallet_bucket(doc.to_dict() or {}, "amount")
            for doc in daily_docs
            if (doc.to_dict() or {}).get("status") in ("pending", "paid")
        )
        if amount > settings["dailyLimit"] - already_withdrawn:
            raise DailyLimitExceeded

        wallet_snapshot = wallet_ref.get(transaction=tx)
        wallet = wallet_snapshot.to_dict() if wallet_snapshot.exists else {}
        winnings = _wallet_bucket(wallet, "winnings")
        if amount > winnings:
            raise InsufficientFunds

        updated_wallet = apply(
            g.uid,
            {
                "deltas": {"winnings": -amount},
                "kind": "withdraw",
                "title": "Withdrawal request",
                "amt": amount,
                "dir": "out",
                "status": "pending",
                "ref": withdrawal_ref.id,
            },
            tx,
        )
        ledger_id_holder["id"] = updated_wallet["ledgerId"]
        tx.create(
            withdrawal_ref,
            {
                "uid": g.uid,
                "amount": amount,
                "upi": upi,
                "dayKey": day_key,
                "status": "pending",
                "transactionId": ledger_id_holder["id"],
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        tx.set(lock_ref, {"withdrawalId": withdrawal_ref.id})
        return updated_wallet

    try:
        wallet = run_transaction(db, operation)
    except AccountOnHold:
        return held_error()
    except UserNotFound:
        return api_error("User profile was not found. Please sign in again.", 401)
    except MissingUpi:
        return api_error("Save a UPI ID before requesting a withdrawal.", 400)
    except WithdrawalPending:
        return api_error("A withdrawal request is already pending.", 409)
    except DailyLimitExceeded:
        return api_error("This withdrawal exceeds your remaining daily limit.", 400)
    except InsufficientFunds:
        return api_error("Withdrawal amount exceeds your winnings balance.", 400)
    tx_snapshot = db.collection("transactions").document(ledger_id_holder["id"]).get()
    return jsonify(
        {
            "ok": True,
            "tx": _transaction_item(ledger_id_holder["id"], tx_snapshot.to_dict() or {}),
            "wallet": {key: value for key, value in wallet.items() if key != "ledgerId"},
        }
    ), 201


@api.post("/api/wallet/winnings-to-deposit")
@require_auth
def winnings_to_deposit() -> tuple[Any, int]:
    body, error = _json_body()
    if error:
        return error
    amount, error = _amount(body.get("amount"))
    if error:
        return error
    db = get_db()
    user_ref = db.collection("users").document(g.uid)
    ledger_id: dict[str, str] = {}

    def operation(tx: Any) -> dict[str, Any]:
        user_snapshot = user_ref.get(transaction=tx)
        if not user_snapshot.exists:
            raise UserNotFound
        if _is_held(user_snapshot.to_dict() or {}):
            raise AccountOnHold
        wallet = apply(
            g.uid,
            {
                "deltas": {"winnings": -amount, "deposited": amount},
                "kind": "move",
                "title": "Winnings moved to deposit",
                "amt": amount,
                "dir": "in",
                "status": "paid",
                "ref": "",
            },
            tx,
        )
        ledger_id["id"] = wallet["ledgerId"]
        return wallet

    try:
        wallet = run_transaction(db, operation)
    except AccountOnHold:
        return held_error()
    except UserNotFound:
        return api_error("User profile was not found. Please sign in again.", 401)
    except InsufficientFunds:
        return api_error("Amount exceeds your winnings balance.", 400)
    tx_snapshot = db.collection("transactions").document(ledger_id["id"]).get()
    return jsonify(
        {
            "ok": True,
            "tx": _transaction_item(ledger_id["id"], tx_snapshot.to_dict() or {}),
            "wallet": {key: value for key, value in wallet.items() if key != "ledgerId"},
        }
    ), 200


@api.post("/api/profile/game-id")
@require_auth
def save_game_id() -> tuple[Any, int]:
    body, error = _json_body()
    if error:
        return error
    ign = body.get("ign")
    game_uid = body.get("uid")
    if not isinstance(ign, str):
        return api_error("IGN must be 2-20 characters.", 400)
    ign = re.sub(r"\s+", " ", ign.strip())
    if not 2 <= len(ign) <= 20:
        return api_error("IGN must be 2-20 characters.", 400)
    if not isinstance(game_uid, str) or not GAME_UID_PATTERN.fullmatch(game_uid):
        return api_error("Game UID must contain 8-12 digits.", 400)

    db = get_db()
    user_ref = db.collection("users").document(g.uid)
    new_uid_ref = db.collection("gameUids").document(game_uid)

    def operation(tx: Any) -> None:
        user_snapshot = user_ref.get(transaction=tx)
        if not user_snapshot.exists:
            raise UserNotFound
        user = user_snapshot.to_dict() or {}
        if _is_held(user):
            raise AccountOnHold
        claim_snapshot = new_uid_ref.get(transaction=tx)
        claim = claim_snapshot.to_dict() if claim_snapshot.exists else {}
        if claim_snapshot.exists and claim.get("uid") != g.uid:
            raise GameUidInUse
        old_game_uid = user.get("gameUid", "")
        old_ref = (
            db.collection("gameUids").document(old_game_uid)
            if isinstance(old_game_uid, str) and old_game_uid and old_game_uid != game_uid
            else None
        )
        old_snapshot = old_ref.get(transaction=tx) if old_ref is not None else None
        if old_ref is not None and old_snapshot is not None:
            old_claim = old_snapshot.to_dict() if old_snapshot.exists else {}
        else:
            old_claim = {}
        tx.set(
            new_uid_ref,
            {"uid": g.uid, "createdAt": firestore.SERVER_TIMESTAMP},
        )
        if old_ref is not None and old_claim.get("uid") == g.uid:
            tx.delete(old_ref)
        tx.set(
            user_ref,
            {
                "ign": ign,
                "gameUid": game_uid,
                "gameOk": True,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

    try:
        run_transaction(db, operation)
    except AccountOnHold:
        return held_error()
    except UserNotFound:
        return api_error("User profile was not found. Please sign in again.", 401)
    except GameUidInUse:
        return api_error("This UID is already linked to another account.", 409)
    return jsonify({"ok": True, "ign": ign, "uid": game_uid}), 200


@api.post("/api/profile/upi")
@require_auth
def save_upi() -> tuple[Any, int]:
    upi = request.form.get("upi", "")
    if not UPI_PATTERN.fullmatch(upi):
        return api_error("Enter a valid UPI ID.", 400)
    upload = request.files.get("shot")
    bucket = get_storage_bucket()
    shot_uploaded = False
    blob = None
    if bucket is not None and upload is not None and upload.filename:
        suffix = "." + upload.filename.rsplit(".", 1)[-1].lower() if "." in upload.filename else ""
        content_type = SHOT_TYPES.get(suffix)
        if content_type is None or upload.mimetype not in (
            content_type,
            "image/jpg" if suffix in (".jpg", ".jpeg") else content_type,
        ):
            return api_error("Screenshot must be a JPG, PNG, or WebP image.", 400)
        data = upload.read(5 * 1024 * 1024 + 1)
        if len(data) > 5 * 1024 * 1024:
            return api_error("Screenshot must be 5 MB or smaller.", 413)
        if not _matches_image_type(data, content_type):
            return api_error("Screenshot contents do not match its image type.", 400)
        blob = bucket.blob(f"users/{g.uid}/upi.jpg")
        blob.upload_from_string(data, content_type=content_type)
        shot_uploaded = True

    db = get_db()
    user_ref = db.collection("users").document(g.uid)

    def operation(tx: Any) -> None:
        snapshot = user_ref.get(transaction=tx)
        if not snapshot.exists:
            raise UserNotFound
        if _is_held(snapshot.to_dict() or {}):
            raise AccountOnHold
        tx.set(
            user_ref,
            {
                "upi": upi,
                "upiShot": shot_uploaded,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

    try:
        run_transaction(db, operation)
    except AccountOnHold:
        if blob is not None:
            blob.delete()
        return held_error()
    except UserNotFound:
        if blob is not None:
            blob.delete()
        return api_error("User profile was not found. Please sign in again.", 401)
    except Exception:
        if blob is not None:
            blob.delete()
        raise
    return jsonify({"ok": True, "upi": upi, "has_shot": shot_uploaded}), 200


@api.get("/api/profile/game-status")
@require_auth
def game_status() -> tuple[Any, int]:
    user, error = _require_user()
    if error:
        return error
    return jsonify({"ok": True, "ready": bool(user.get("gameOk"))}), 200


@api.post("/api/profile/fcm-token")
@require_auth
def save_fcm_token() -> tuple[Any, int]:
    body, error = _json_body()
    if error:
        return error
    if body.get("remove") is True and "token" not in body:
        return _save_user_fields({"fcmToken": firestore.DELETE_FIELD})
    token = body.get("token")
    if not isinstance(token, str) or not token.strip() or len(token) > 4096:
        return api_error("A valid FCM token is required.", 400)
    return _save_user_fields({"fcmToken": token.strip()})


@api.post("/api/profile/notif-settings")
@require_auth
def save_notif_settings() -> tuple[Any, int]:
    body, error = _json_body()
    if error:
        return error
    settings = {}
    for key in ("push", "reminders", "results"):
        if not isinstance(body.get(key), bool):
            return api_error(f"{key} must be a boolean.", 400)
        settings[key] = body[key]
    return _save_user_fields({"notifSettings": settings})


@api.get("/api/notifications")
@require_auth
def get_notifications() -> tuple[Any, int]:
    try:
        limit = int(request.args.get("limit", "30"))
    except ValueError:
        return api_error("limit must be an integer between 1 and 100.", 400)
    if not 1 <= limit <= 100:
        return api_error("limit must be an integer between 1 and 100.", 400)
    query = (
        get_db()
        .collection("notifications")
        .where("uid", "==", g.uid)
        .order_by("createdAt", direction=firestore.Query.DESCENDING)
        .limit(limit)
    )
    notifications = []
    for snapshot in query.stream():
        item = snapshot.to_dict() or {}
        item["id"] = snapshot.id
        item["date"] = _format_date(item.get("createdAt"))
        notifications.append(item)
    return jsonify({"ok": True, "notifications": notifications}), 200


@api.post("/api/notifications/read-all")
@require_auth
def read_all_notifications() -> tuple[Any, int]:
    db = get_db()
    snapshots = (
        db.collection("notifications")
        .where("uid", "==", g.uid)
        .stream()
    )
    batch = db.batch()
    count = 0
    for snapshot in snapshots:
        notification = snapshot.to_dict() or {}
        if notification.get("read") is True:
            continue
        batch.update(snapshot.reference, {"read": True, "readAt": firestore.SERVER_TIMESTAMP})
        count += 1
        if count % 450 == 0:
            batch.commit()
            batch = db.batch()
    if count % 450:
        batch.commit()
    return jsonify({"ok": True, "updated": count}), 200


def _session_response(user: dict[str, Any], uid: str) -> dict[str, Any]:
    db = get_db()
    wallet = wallet_for(uid, db)
    settings = get_settings(db)
    limits = _public_limits(settings)
    return {
        "ok": True,
        "user": {
            "uid": uid,
            "name": user.get("name", "Player"),
            "email": user.get("email", ""),
            "picture": user.get("picture") or None,
            "ign": user.get("ign", ""),
            "gameUid": user.get("gameUid", ""),
            "upi": user.get("upi", ""),
            "hasUpiShot": bool(user.get("upiShot", user.get("has_upi_shot", False))),
            "notifSettings": user.get(
                "notifSettings",
                {"push": True, "reminders": True, "results": True},
            ),
        },
        "wallet": wallet,
        "gameOk": bool(user.get("gameOk", user.get("game_ok", False))),
        "hasUpi": bool(user.get("upi")),
        "dailyLeft": _daily_left(db, uid, settings),
        "limits": limits,
        "paymentMethod": get_add_money_method(settings),
        "maintenance": maintenance_info(settings),
    }


def _require_user() -> tuple[dict[str, Any] | None, tuple[Any, int] | None]:
    snapshot = get_db().collection("users").document(g.uid).get()
    if not snapshot.exists:
        return None, api_error("User profile was not found. Please sign in again.", 401)
    user = snapshot.to_dict() or {}
    return user, None


def _save_user_fields(fields: dict[str, Any]) -> tuple[Any, int]:
    db = get_db()
    user_ref = db.collection("users").document(g.uid)

    def operation(tx: Any) -> None:
        snapshot = user_ref.get(transaction=tx)
        if not snapshot.exists:
            raise UserNotFound
        if _is_held(snapshot.to_dict() or {}):
            raise AccountOnHold
        tx.set(
            user_ref,
            {**fields, "updatedAt": firestore.SERVER_TIMESTAMP},
            merge=True,
        )

    try:
        run_transaction(db, operation)
    except AccountOnHold:
        return held_error()
    except UserNotFound:
        return api_error("User profile was not found. Please sign in again.", 401)
    return jsonify({"ok": True}), 200


def _daily_left(db: Any, uid: str, settings: dict[str, Any]) -> int:
    day_key = datetime.now(IST).strftime("%Y-%m-%d")
    docs = (
        db.collection("withdrawals")
        .where("uid", "==", uid)
        .where("dayKey", "==", day_key)
        .stream()
    )
    used = sum(
        _wallet_bucket(item.to_dict() or {}, "amount")
        for item in docs
        if (item.to_dict() or {}).get("status") in ("pending", "paid")
    )
    return settings["dailyLimit"] - used


def _public_limits(settings: dict[str, Any]) -> dict[str, int]:
    return {
        key: settings[key]
        for key in ("minAdd", "maxAdd", "minWithdraw", "dailyLimit")
    }


def _json_body() -> tuple[dict[str, Any], tuple[Any, int] | None]:
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return {}, api_error("Request body must be valid JSON.", 400)
    return body, None


def _amount(value: Any) -> tuple[int, tuple[Any, int] | None]:
    if isinstance(value, bool):
        return 0, api_error("Amount must be a whole number of rupees.", 400)
    if isinstance(value, int):
        amount = value
    elif isinstance(value, str) and re.fullmatch(r"\d+", value.strip()):
        amount = int(value.strip())
    else:
        return 0, api_error("Amount must be a whole number of rupees.", 400)
    if amount < 1:
        return 0, api_error("Amount must be at least 1 rupee.", 400)
    return amount, None


def _wallet_bucket(wallet: dict[str, Any], name: str) -> int:
    value = wallet.get(name, 0)
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{name} must be a whole number.")
    return value


def _format_rupees(amount: Any) -> str:
    if isinstance(amount, bool) or not isinstance(amount, int):
        amount = 0
    digits = str(abs(amount))
    if len(digits) <= 3:
        grouped = digits
    else:
        head, tail = digits[:-3], digits[-3:]
        parts = []
        while head:
            parts.append(head[-2:])
            head = head[:-2]
        grouped = ",".join(reversed(parts)) + "," + tail
    return f"-{grouped}" if amount < 0 else grouped


def _format_date(value: Any) -> str:
    if not isinstance(value, datetime):
        return ""
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    local = value.astimezone(IST)
    return f"{local.day} {local.strftime('%b, %I:%M %p')}"


def _matches_image_type(data: bytes, content_type: str) -> bool:
    if content_type == "image/jpeg":
        return data.startswith(b"\xff\xd8\xff")
    if content_type == "image/png":
        return data.startswith(b"\x89PNG\r\n\x1a\n")
    return (
        content_type == "image/webp"
        and len(data) >= 12
        and data[:4] == b"RIFF"
        and data[8:12] == b"WEBP"
    )


def _transaction_item(identifier: str, entry: dict[str, Any]) -> dict[str, Any]:
    created_at = entry.get("createdAt")
    wait_left = None
    if entry.get("kind") == "added" and entry.get("status") == "pending":
        if isinstance(created_at, datetime):
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
            wait_left = max(
                0,
                4 * 60 * 60
                - int((datetime.now(timezone.utc) - created_at).total_seconds()),
            )
        else:
            wait_left = 4 * 60 * 60
    return {
        "id": identifier,
        "kind": entry.get("kind", ""),
        "title": entry.get("title", ""),
        "date": _format_date(entry.get("createdAt")),
        "amt": _format_rupees(entry.get("amt", 0)),
        "dir": entry.get("dir", ""),
        "status": entry.get("status", ""),
        "waitLeft": wait_left,
    }


def _is_held(user: dict[str, Any]) -> bool:
    return user.get("isHeld") is True or user.get("is_held") is True


class UserNotFound(Exception):
    pass


class DuplicateUtr(Exception):
    pass


class MissingUpi(Exception):
    pass


class WithdrawalPending(Exception):
    pass


class DailyLimitExceeded(Exception):
    pass


class GameUidInUse(Exception):
    pass
