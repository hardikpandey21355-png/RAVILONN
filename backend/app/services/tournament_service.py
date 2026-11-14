from datetime import datetime, timedelta, timezone
import hashlib
import math
from typing import Any
from urllib.parse import quote
import secrets

from firebase_admin import firestore
from flask import current_app
from werkzeug.utils import secure_filename
from zoneinfo import ZoneInfo

from app.core.firestore import get_db, get_storage_bucket, run_transaction
from app.services.notification_service import deliver_to_user, notify_users
from app.services.user_service import AccountOnHold
from app.services.wallet_service import (
    apply,
    entry_fee_deltas,
    wallet_for,
)


IST = ZoneInfo("Asia/Kolkata")
TEAMS = {"Solo", "Duo", "Squad"}
TEAM_SIZES = {"Solo": 1, "Duo": 2, "Squad": 4}
MAX_PRIZES = 20
MAX_BANNER_BYTES = 4 * 1024 * 1024
MIME_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


class TournamentInputError(ValueError):
    pass


class TournamentJoinError(ValueError):
    pass


class SlotAlreadyTaken(TournamentJoinError):
    pass


class AlreadyJoined(TournamentJoinError):
    pass


class MissingGameId(TournamentJoinError):
    pass


class TournamentNotJoinable(TournamentJoinError):
    pass


def list_tournaments(db: Any = None) -> list[dict[str, Any]]:
    database = db or get_db()
    now = datetime.now(timezone.utc)
    tournaments = [
        _present(snapshot.id, snapshot.to_dict() or {}, now)
        for snapshot in database.collection("tournaments").stream()
    ]
    return sorted(
        tournaments,
        key=lambda item: (
            item.get("_startAt") or datetime.max.replace(tzinfo=timezone.utc),
            item["id"],
        ),
    )


def list_joined_players(tournament_id: str, db: Any = None) -> tuple[dict[str, Any] | None, list[dict[str, Any]]]:
    database = db or get_db()
    tournament_snapshot = database.collection("tournaments").document(tournament_id).get()
    if not tournament_snapshot.exists:
        return None, []
    now = datetime.now(timezone.utc)
    tournament = _present(
        tournament_id,
        tournament_snapshot.to_dict() or {},
        now,
    )
    entries = (
        database.collection("tournamentEntries")
        .where("tournamentId", "==", tournament_id)
        .stream()
    )
    rows = []
    for entry in entries:
        value = entry.to_dict() or {}
        rows.append(
            {
                "slot": _safe_int(value.get("slot"), 0),
                "ign": value.get("ign", ""),
                "game_uid": value.get("gameUid", ""),
            }
        )
    rows.sort(key=lambda row: row["slot"])
    tournament["joined"] = len(rows)
    tournament["players"] = f"{len(rows)}/{tournament['slots']}"
    return tournament, rows


def slots_for_tournament(
    tournament_id: str,
    uid: str,
    db: Any = None,
) -> dict[str, Any]:
    database = db or get_db()
    tournament_ref = database.collection("tournaments").document(tournament_id)
    snapshot = tournament_ref.get()
    if not snapshot.exists:
        raise TournamentNotJoinable("Tournament was not found.")
    value = snapshot.to_dict() or {}
    team_slots = _safe_int(value.get("slots"), 0)
    team_size = _team_size(value.get("team"))
    entries = list(
        database.collection("tournamentEntries")
        .where("tournamentId", "==", tournament_id)
        .stream()
    )
    taken = sorted(
        _safe_int((entry.to_dict() or {}).get("slot"), 0)
        for entry in entries
    )
    taken_set = set(taken)
    reserved = []
    stored_reserved = value.get("reservedSlots")
    if (
        value.get("simulatedSlotsEnabled") is not True
        or not isinstance(stored_reserved, list)
    ):
        stored_reserved = []
    for slot in stored_reserved:
        if (
            isinstance(slot, int)
            and not isinstance(slot, bool)
            and 1 <= slot <= team_slots * team_size
            and slot not in taken_set
            and slot not in reserved
        ):
            reserved.append(slot)
    mine = next(
        (
            entry.to_dict() or {}
            for entry in entries
            if (entry.to_dict() or {}).get("uid") == uid
        ),
        {},
    )
    return {
        "slots": team_slots * team_size,
        "teamSlots": team_slots,
        "teamSize": team_size,
        "taken": taken,
        "reserved": reserved,
        "joined": bool(mine),
        "mySlot": mine.get("slot"),
    }


def joined_tournament_ids(uid: str, db: Any = None) -> set[str]:
    database = db or get_db()
    entries = (
        database.collection("tournamentEntries")
        .where("uid", "==", uid)
        .stream()
    )
    return {
        value["tournamentId"]
        for entry in entries
        if isinstance((value := entry.to_dict() or {}).get("tournamentId"), str)
    }


def joined_tournament_slots(uid: str, db: Any = None) -> dict[str, int]:
    database = db or get_db()
    entries = (
        database.collection("tournamentEntries")
        .where("uid", "==", uid)
        .stream()
    )
    return {
        value["tournamentId"]: value["slot"]
        for entry in entries
        if isinstance((value := entry.to_dict() or {}).get("tournamentId"), str)
        and isinstance(value.get("slot"), int)
    }


def joined_matches(uid: str, db: Any = None) -> list[dict[str, Any]]:
    database = db or get_db()
    entries = (
        database.collection("tournamentEntries")
        .where("uid", "==", uid)
        .stream()
    )
    matches = []
    seen: set[str] = set()
    for entry in entries:
        entry_value = entry.to_dict() or {}
        tournament_id = entry_value.get("tournamentId")
        if not isinstance(tournament_id, str) or not tournament_id or tournament_id in seen:
            continue
        seen.add(tournament_id)

        tournament_snapshot = (
            database.collection("tournaments").document(tournament_id).get()
        )
        if not tournament_snapshot.exists:
            continue
        tournament = _present(
            tournament_id,
            tournament_snapshot.to_dict() or {},
            datetime.now(timezone.utc),
        )
        if tournament.get("isDeleting") is True or tournament["status"] == "deleting":
            continue

        result_id = hashlib.sha256(f"{tournament_id}:{uid}".encode()).hexdigest()
        result_snapshot = (
            database.collection("tournamentResults").document(result_id).get()
        )
        result = result_snapshot.to_dict() if result_snapshot.exists else {}
        result = result or {}
        declared = result.get("status") == "approved"
        matches.append(
            {
                "id": f"match_{tournament_id}",
                "tournamentId": tournament_id,
                "mySlot": _safe_int(entry_value.get("slot"), 0),
                "mode": tournament.get("mode", ""),
                "team": tournament.get("team", ""),
                "map": tournament.get("map", ""),
                "fee": tournament["fee"],
                "joined": tournament["joined"],
                "slots": tournament["slots"],
                "perKill": tournament["per_kill"],
                "prize": tournament["prize"],
                "durationMin": tournament["duration_min"],
                "secs": tournament["secs"],
                "status": tournament["status"],
                "when": tournament["when"],
                "bg": tournament["bg"],
                "bannerUrl": tournament["bannerUrl"],
                "loot": tournament["loot"],
                "roomId": tournament["room_id"],
                "roomPass": tournament["room_pass"],
                "result": {
                    "declared": declared,
                    "won": _safe_int(result.get("amount"), 0) if declared else 0,
                },
                "_startAt": tournament["_startAt"],
            }
        )

    return sorted(
        matches,
        key=lambda item: (
            1 if item["status"] == "completed" else 0,
            -item["_startAt"].timestamp()
            if item["status"] == "completed"
            else item["_startAt"].timestamp(),
            item["tournamentId"],
        ),
    )


def save_room_details(
    tournament_id: str,
    room_id: str,
    room_pass: str,
    db: Any = None,
) -> tuple[dict[str, Any], bool]:
    room_id = room_id.strip()
    room_pass = room_pass.strip()
    if len(room_id) > 20 or len(room_pass) > 20:
        raise TournamentInputError("Room ID and password must be 20 characters or fewer.")
    if bool(room_id) != bool(room_pass):
        raise TournamentInputError("Enter both the room ID and password, or leave both empty.")

    database = db or get_db()
    tournament_ref = database.collection("tournaments").document(tournament_id)
    result: dict[str, Any] = {}

    def operation(tx: Any) -> None:
        snapshot = tournament_ref.get(transaction=tx)
        if not snapshot.exists:
            raise TournamentInputError("Tournament was not found.")
        tournament = snapshot.to_dict() or {}
        changed = (
            tournament.get("roomId", "") != room_id
            or tournament.get("roomPass", "") != room_pass
        )
        if changed:
            tx.update(
                tournament_ref,
                {
                    "roomId": room_id,
                    "roomPass": room_pass,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
            )
        result.update(
            {
                "mode": tournament.get("mode", "Tournament"),
                "roomId": room_id,
                "roomPass": room_pass,
                "changed": changed,
            }
        )

    run_transaction(database, operation)
    if not result["changed"] or not room_id:
        return result, False

    entries = (
        database.collection("tournamentEntries")
        .where("tournamentId", "==", tournament_id)
        .stream()
    )
    recipients = list(
        dict.fromkeys(
            value["uid"]
            for entry in entries
            if isinstance((value := entry.to_dict() or {}).get("uid"), str)
        )
    )
    body = (
        f"Your room details for {result['mode']} are ready. "
        f"Room ID: {room_id}. Password: {room_pass}. "
        "Open My Matches to view them and join on time."
    )
    counts = notify_users(
        recipients,
        "Tournament room details are ready",
        body,
        "/matches",
        category="tournament_room",
        db=database,
    )
    result["notificationCounts"] = counts
    return result, True


def join_tournament(
    uid: str,
    tournament_id: str,
    slot: int,
    db: Any = None,
) -> dict[str, Any]:
    if isinstance(slot, bool) or not isinstance(slot, int) or slot < 1:
        raise TournamentJoinError("Choose a valid slot.")
    database = db or get_db()
    user_ref = database.collection("users").document(uid)
    tournament_ref = database.collection("tournaments").document(tournament_id)
    entry_id = hashlib.sha256(f"{tournament_id}:{uid}".encode()).hexdigest()
    entry_ref = database.collection("tournamentEntries").document(entry_id)
    slot_ref = database.collection("tournamentSlotClaims").document(
        f"{tournament_id}_{slot}"
    )
    result: dict[str, Any] = {}

    def operation(tx: Any) -> None:
        user_snapshot = user_ref.get(transaction=tx)
        tournament_snapshot = tournament_ref.get(transaction=tx)
        existing_entry = entry_ref.get(transaction=tx)
        slot_snapshot = slot_ref.get(transaction=tx)

        if not user_snapshot.exists:
            raise TournamentJoinError("Complete your profile before joining.")
        user = user_snapshot.to_dict() or {}
        if user.get("isHeld") is True or user.get("is_held") is True:
            raise AccountOnHold
        game_uid = user.get("gameUid", "")
        ign = user.get("ign", "")
        if user.get("gameOk") is not True or not isinstance(game_uid, str) or not game_uid:
            raise MissingGameId
        if existing_entry.exists:
            raise AlreadyJoined("You have already joined this tournament.")
        if not tournament_snapshot.exists:
            raise TournamentNotJoinable("Tournament was not found.")
        tournament = tournament_snapshot.to_dict() or {}
        if tournament.get("isDeleting") is True:
            raise TournamentNotJoinable("This tournament is being deleted.")
        now = datetime.now(timezone.utc)
        presented = _present(tournament_id, tournament, now)
        if presented["status"] != "upcoming":
            raise TournamentNotJoinable("This tournament is no longer open for joining.")
        slots = _safe_int(tournament.get("slots"), 0) * _team_size(
            tournament.get("team")
        )
        if slot > slots:
            raise TournamentJoinError("Choose a valid slot.")
        stored_reserved = tournament.get("reservedSlots")
        if not isinstance(stored_reserved, list):
            stored_reserved = []
        simulated_enabled = tournament.get("simulatedSlotsEnabled") is True
        reserved_slots = [
            reserved_slot
            for reserved_slot in stored_reserved
            if isinstance(reserved_slot, int)
            and not isinstance(reserved_slot, bool)
        ] if simulated_enabled else []
        if slot in reserved_slots:
            raise SlotAlreadyTaken("That slot is reserved and will open later.")
        if slot_snapshot.exists:
            raise SlotAlreadyTaken("That slot was just taken. Choose another slot.")

        fee = _safe_int(tournament.get("fee"), 0)
        wallet = None
        if fee:
            wallet_snapshot = (
                database.collection("wallets")
                .document(uid)
                .get(transaction=tx)
            )
            balances = wallet_snapshot.to_dict() if wallet_snapshot.exists else {}
            wallet = apply(
                uid,
                {
                    "deltas": entry_fee_deltas(balances, fee),
                    "kind": "entry_fee",
                    "title": "Entry fee",
                    "amt": fee,
                    "dir": "out",
                    "status": "paid",
                    "ref": tournament_id,
                },
                tx,
            )
        tx.create(
            entry_ref,
            {
                "tournamentId": tournament_id,
                "uid": uid,
                "slot": slot,
                "ign": ign,
                "gameUid": game_uid,
                "joinedAt": firestore.SERVER_TIMESTAMP,
            },
        )
        tx.create(
            slot_ref,
            {
                "tournamentId": tournament_id,
                "uid": uid,
                "entryId": entry_id,
                "slot": slot,
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
        tx.update(
            tournament_ref,
            {
                "joinedCount": _safe_int(tournament.get("joinedCount"), 0) + 1,
                "reservedSlots": reserved_slots[:-1]
                if simulated_enabled and reserved_slots
                else reserved_slots,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
        )
        result.update(
            {
                "slot": slot,
                "wallet": wallet,
                "fee": fee,
            }
        )

    run_transaction(database, operation)
    if result["wallet"] is None:
        result["wallet"] = wallet_for(uid, database)
    return result


def set_simulated_slots(
    tournament_id: str,
    enabled: bool,
    count: int,
    db: Any = None,
) -> dict[str, Any]:
    if not isinstance(enabled, bool):
        raise TournamentInputError("Choose whether simulated slots are on or off.")
    if isinstance(count, bool) or not isinstance(count, int) or count < 0:
        raise TournamentInputError("Enter a valid reserved seat count.")

    database = db or get_db()
    tournament_ref = database.collection("tournaments").document(tournament_id)
    result: dict[str, Any] = {}

    def operation(tx: Any) -> None:
        snapshot = tournament_ref.get(transaction=tx)
        if not snapshot.exists:
            raise TournamentInputError("Tournament was not found.")
        tournament = snapshot.to_dict() or {}
        capacity = _safe_int(tournament.get("slots"), 0) * _team_size(
            tournament.get("team")
        )
        if count > capacity:
            raise TournamentInputError(
                f"Reserved seats cannot exceed the tournament capacity of {capacity}."
            )

        entries = (
            database.collection("tournamentEntries")
            .where("tournamentId", "==", tournament_id)
            .stream(transaction=tx)
        )
        taken = {
            _safe_int((entry.to_dict() or {}).get("slot"), 0)
            for entry in entries
        }
        available = [
            slot for slot in range(1, capacity + 1) if slot not in taken
        ]
        reserved = (
            secrets.SystemRandom().sample(available, min(count, len(available)))
            if enabled
            else []
        )
        tx.update(
            tournament_ref,
            {
                "simulatedSlotsEnabled": enabled,
                "simulatedSlotsCount": count,
                "reservedSlots": reserved,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
        )
        tournament.update(
            {
                "simulatedSlotsEnabled": enabled,
                "simulatedSlotsCount": count,
                "reservedSlots": reserved,
            }
        )
        result.update(tournament)

    run_transaction(database, operation)
    return _present(
        tournament_id,
        result,
        datetime.now(timezone.utc),
    )


def list_defaults(loot: bool = False, db: Any = None) -> list[dict[str, Any]]:
    database = db or get_db()
    results = []
    for snapshot in database.collection("tournamentDefaults").stream():
        value = snapshot.to_dict() or {}
        if value.get("loot") is loot:
            results.append(_default_present(snapshot.id, value))
    return sorted(results, key=lambda item: item["name"].casefold())


def dashboard_counts(db: Any = None) -> dict[str, int]:
    tournaments = list_tournaments(db)
    return {
        "total": len(tournaments),
        "live": sum(item["status"] == "live" for item in tournaments),
        "upcoming": sum(item["status"] == "upcoming" for item in tournaments),
        "completed": sum(item["status"] == "completed" for item in tournaments),
        "joined": sum(item["joined"] for item in tournaments),
        "slots": sum(item["slots"] for item in tournaments),
    }


def create_tournament(
    payload: dict[str, Any],
    *,
    save_as_default: bool = False,
    banner_file: Any = None,
    db: Any = None,
) -> dict[str, Any]:
    database = db or get_db()
    data = validate_tournament(payload)
    tournament_ref = database.collection("tournaments").document()
    player_slots = _safe_int(data.get("slots"), 0) * _team_size(data.get("team"))
    requested_reserved_count = payload.get(
        "simulatedSlotsCount",
        payload.get("simulated_slots_count"),
    )
    simulated_slots_count = (
        0
        if requested_reserved_count in (None, "")
        else _integer(
            requested_reserved_count,
            "Reserved seats",
            0,
            player_slots,
        )
    )
    reserved_slots = secrets.SystemRandom().sample(
        range(1, player_slots + 1),
        simulated_slots_count,
    )
    default_ref = (
        database.collection("tournamentDefaults").document()
        if save_as_default
        else None
    )
    uploaded_blob = None

    if banner_file is not None and banner_file.filename:
        bucket = get_storage_bucket()
        if bucket is None:
            raise TournamentInputError(
                "Banner uploads require STORAGE_BUCKET. Choose an existing banner instead."
            )
        banner_url, uploaded_blob = _upload_banner(
            bucket,
            tournament_ref.id,
            banner_file,
        )
        data["bannerUrl"] = banner_url

    tournament_data = {
        **data,
        "joinedCount": 0,
        "simulatedSlotsEnabled": simulated_slots_count > 0,
        "simulatedSlotsCount": simulated_slots_count,
        "reservedSlots": reserved_slots,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    batch = database.batch()
    batch.set(tournament_ref, tournament_data)
    if default_ref is not None:
        batch.set(
            default_ref,
            {
                **data,
                "name": data["mode"],
                "createdAt": firestore.SERVER_TIMESTAMP,
            },
        )
    try:
        batch.commit()
    except Exception:
        if uploaded_blob is not None:
            uploaded_blob.delete()
        raise
    return _present(tournament_ref.id, tournament_data, datetime.now(timezone.utc))


def create_from_default(
    default_id: str,
    start_value: Any,
    simulated_slots_count: Any = 0,
    db: Any = None,
) -> dict[str, Any]:
    database = db or get_db()
    default_ref = database.collection("tournamentDefaults").document(default_id)
    snapshot = default_ref.get()
    if not snapshot.exists:
        raise TournamentInputError("Default tournament was not found.")
    default = snapshot.to_dict() or {}
    data = {key: value for key, value in default.items() if key not in {"createdAt", "name"}}
    data["duration"] = data.get("durationMin")
    data["per_kill"] = data.get("perKill")
    data["banner_pick"] = data.get("banner", "")
    data["start"] = _parse_start(start_value)
    data["simulatedSlotsCount"] = simulated_slots_count
    return create_tournament(data, db=database)


def delete_default(default_id: str, db: Any = None) -> None:
    database = db or get_db()
    database.collection("tournamentDefaults").document(default_id).delete()


def delete_tournament(tournament_id: str, db: Any = None) -> dict[str, int]:
    database = db or get_db()
    tournament_ref = database.collection("tournaments").document(tournament_id)
    tournament_data: dict[str, Any] = {}

    def mark_for_deletion(tx: Any) -> None:
        snapshot = tournament_ref.get(transaction=tx)
        if not snapshot.exists:
            raise TournamentInputError("Tournament was not found.")
        value = snapshot.to_dict() or {}
        if not value.get("isDeleting"):
            tx.update(
                tournament_ref,
                {
                    "isDeleting": True,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
            )
        tournament_data.update(value)

    run_transaction(database, mark_for_deletion)
    fee = _safe_int(tournament_data.get("fee"), 0)
    entries = (
        database.collection("tournamentEntries")
        .where("tournamentId", "==", tournament_id)
        .stream()
    )
    refunded_players = 0
    refunded_amount = 0
    cancellation_notifications: list[tuple[str, str, str, str]] = []

    for entry in entries:
        entry_ref = database.collection("tournamentEntries").document(entry.id)
        refund: dict[str, int] = {}
        removed: dict[str, str] = {}

        def remove_entry(tx: Any) -> None:
            entry_snapshot = entry_ref.get(transaction=tx)
            tournament_snapshot = tournament_ref.get(transaction=tx)
            if not entry_snapshot.exists or not tournament_snapshot.exists:
                return

            current_entry = entry_snapshot.to_dict() or {}
            uid = current_entry.get("uid")
            current_slot = _safe_int(current_entry.get("slot"), 0)
            if not isinstance(uid, str) or not uid:
                raise TournamentInputError(
                    "A joined player is missing their account ID; deletion was stopped."
                )
            if fee:
                refund.update(
                    apply(
                        uid,
                        {
                            "deltas": {"deposited": fee},
                            "kind": "refund",
                            "title": "Tournament cancellation refund",
                            "amt": fee,
                            "dir": "in",
                            "status": "paid",
                            "ref": tournament_id,
                        },
                        tx,
                    )
                )

            notification_id = hashlib.sha256(
                f"tournament-cancel:{tournament_id}:{uid}".encode()
            ).hexdigest()
            notification_ref = database.collection("notifications").document(
                notification_id
            )
            title = "Tournament cancelled"
            body = (
                "The tournament you joined has been cancelled due to unforeseen "
                f"circumstances. Your entry fee of ₹{fee} has been refunded to "
                "your deposited wallet."
                if fee
                else (
                    "The tournament you joined has been cancelled due to "
                    "unforeseen circumstances. No entry fee was charged."
                )
            )
            tx.create(
                notification_ref,
                {
                    "uid": uid,
                    "title": title,
                    "body": body,
                    "link": "/notifications",
                    "category": "tournament_cancel",
                    "read": False,
                    "createdAt": firestore.SERVER_TIMESTAMP,
                },
            )
            tx.delete(entry_ref)
            tx.delete(
                database.collection("tournamentSlotClaims").document(
                    f"{tournament_id}_{current_slot}"
                )
            )
            tournament = tournament_snapshot.to_dict() or {}
            tx.update(
                tournament_ref,
                {
                    "joinedCount": max(
                        0, _safe_int(tournament.get("joinedCount"), 0) - 1
                    ),
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
            )
            removed.update(
                {
                    "uid": uid,
                    "notification_id": notification_id,
                    "title": title,
                    "body": body,
                }
            )

        run_transaction(database, remove_entry)
        if removed:
            cancellation_notifications.append(
                (
                    removed["uid"],
                    removed["notification_id"],
                    removed["title"],
                    removed["body"],
                )
            )
        if fee and refund:
            refunded_players += 1
            refunded_amount += fee

    def finish_deletion(tx: Any) -> None:
        snapshot = tournament_ref.get(transaction=tx)
        if snapshot.exists:
            tx.delete(tournament_ref)

    run_transaction(database, finish_deletion)
    for uid, notification_id, title, body in cancellation_notifications:
        deliver_to_user(
            uid,
            title,
            body,
            "/notifications",
            category="tournament_cancel",
            admin_uid="local-admin",
            notification_id=notification_id,
            db=database,
        )
    return {
        "refunded_players": refunded_players,
        "refunded_amount": refunded_amount,
    }


def validate_tournament(payload: dict[str, Any]) -> dict[str, Any]:
    mode = _text(payload.get("mode"), "Tournament name", 30)
    team = payload.get("team")
    if team not in TEAMS:
        raise TournamentInputError("Choose a valid team type.")
    map_name = _text(payload.get("map"), "Map", 20)
    fee = _integer(payload.get("fee"), "Entry fee", 0, 100000)
    slots = _integer(payload.get("slots"), "Slots", 2, 1000)
    duration = _integer(payload.get("duration"), "Duration", 5, 240)
    per_kill = _integer(payload.get("per_kill"), "Reward per kill", 0, 10000)
    prizes = _prizes(payload.get("place_amt", []))
    is_loot = payload.get("loot") is True
    if is_loot and fee != 0:
        raise TournamentInputError("Loot matches must have free entry.")
    start_at = _parse_start(payload.get("start"))
    if start_at <= datetime.now(IST):
        raise TournamentInputError("Start time must be in the future.")
    if is_loot and start_at.weekday() not in (5, 6):
        raise TournamentInputError("Loot matches can only start on Saturday or Sunday.")

    banner = payload.get("banner_pick") or payload.get("banner", "")
    if not isinstance(banner, str):
        raise TournamentInputError("Choose a valid banner.")
    if banner and secure_filename(banner) != banner:
        raise TournamentInputError("Choose a valid banner.")
    banner_url = payload.get("bannerUrl", "")
    if not isinstance(banner_url, str):
        banner_url = ""
    return {
        "game": "Free Fire",
        "mode": mode,
        "team": team,
        "map": map_name,
        "fee": fee,
        "slots": slots,
        "durationMin": duration,
        "startAt": start_at.astimezone(timezone.utc),
        "perKill": per_kill,
        "prizes": prizes,
        "prize": sum(prizes) + (slots - 1) * per_kill,
        "loot": is_loot,
        "banner": banner or ("loot_banner.jpg" if is_loot else "upcoming.jpg"),
        "bannerUrl": banner_url,
        "roomId": "",
        "roomPass": "",
    }


def _present(
    identifier: str,
    value: dict[str, Any],
    now: datetime,
) -> dict[str, Any]:
    start = value.get("startAt")
    if isinstance(start, datetime):
        if start.tzinfo is None:
            start = start.replace(tzinfo=timezone.utc)
        start = start.astimezone(timezone.utc)
    else:
        start = now
    duration = _safe_int(value.get("durationMin"), 0)
    end = start + timedelta(minutes=duration)
    if now < start:
        status = "upcoming"
        seconds = max(0, math.ceil((start - now).total_seconds()))
        label = "Starts in"
    elif now < end:
        status = "live"
        seconds = max(0, math.ceil((end - now).total_seconds()))
        label = "Ends in"
    else:
        status = "completed"
        seconds = 0
        label = "Ends in"
    if value.get("isDeleting") is True:
        status = "deleting"
        seconds = 0

    local_start = start.astimezone(IST)
    local_now = now.astimezone(IST)
    if status == "live":
        when = "Live now"
    elif status == "completed":
        when = "Completed"
    else:
        date_label = (
            "Today"
            if local_start.date() == local_now.date()
            else "Tomorrow"
            if local_start.date() == (local_now + timedelta(days=1)).date()
            else local_start.strftime("%d %b")
        )
        when = f"{date_label}, {local_start.strftime('%I:%M %p').lstrip('0')}"

    slots = _safe_int(value.get("slots"), 0)
    team_size = _team_size(value.get("team"))
    player_slots = slots * team_size
    joined = _safe_int(value.get("joinedCount"), 0)
    stored_reserved = value.get("reservedSlots")
    if not isinstance(stored_reserved, list):
        stored_reserved = []
    reserved_slots = list(
        dict.fromkeys(
            slot
            for slot in stored_reserved
            if isinstance(slot, int)
            and not isinstance(slot, bool)
            and 1 <= slot <= player_slots
        )
    )
    simulated_slots_enabled = value.get("simulatedSlotsEnabled") is True
    if not simulated_slots_enabled:
        reserved_slots = []
    prizes = value.get("prizes")
    if not isinstance(prizes, list):
        prizes = []
    return {
        **value,
        "id": identifier,
        "mode": value.get("mode", ""),
        "team": value.get("team", ""),
        "map": value.get("map", ""),
        "fee": _safe_int(value.get("fee"), 0),
        "slots": slots,
        "playerSlots": player_slots,
        "teamSize": team_size,
        "joined": joined,
        "simulatedSlotsEnabled": simulated_slots_enabled,
        "simulatedSlotsCount": _safe_int(value.get("simulatedSlotsCount"), 5),
        "reservedSlots": reserved_slots,
        "reservedCount": len(reserved_slots),
        "duration_min": duration,
        "per_kill": _safe_int(value.get("perKill"), 0),
        "prize": _safe_int(value.get("prize"), 0),
        "loot": value.get("loot") is True,
        "room_id": value.get("roomId", ""),
        "room_pass": value.get("roomPass", ""),
        "status": status,
        "players": f"{joined}/{player_slots}",
        "when": when,
        "secs": seconds,
        "label": label,
        "bg": value.get("banner") or ("loot_banner.jpg" if value.get("loot") else "upcoming.jpg"),
        "bannerUrl": value.get("bannerUrl", ""),
        "prizes": prizes,
        "_startAt": start,
    }


def _default_present(identifier: str, value: dict[str, Any]) -> dict[str, Any]:
    slots = _safe_int(value.get("slots"), 0)
    return {
        **value,
        "id": identifier,
        "name": value.get("name") or value.get("mode", ""),
        "duration_min": _safe_int(value.get("durationMin"), 0),
        "per_kill": _safe_int(value.get("perKill"), 0),
        "prize": _safe_int(value.get("prize"), 0),
        "fee": _safe_int(value.get("fee"), 0),
        "slots": slots,
        "playerSlots": slots * _team_size(value.get("team")),
        "loot": value.get("loot") is True,
    }


def _team_size(team: Any) -> int:
    return TEAM_SIZES.get(team, 1)


def _parse_start(value: Any) -> datetime:
    if isinstance(value, datetime):
        result = value
    elif isinstance(value, str) and value.strip():
        try:
            result = datetime.fromisoformat(value.strip())
        except ValueError as error:
            raise TournamentInputError("Choose a valid start date and time.") from error
    else:
        raise TournamentInputError("Choose a start date and time.")
    if result.tzinfo is None:
        result = result.replace(tzinfo=IST)
    return result.astimezone(IST)


def _text(value: Any, label: str, maximum: int) -> str:
    if not isinstance(value, str):
        raise TournamentInputError(f"{label} is required.")
    cleaned = " ".join(value.split())
    if not cleaned or len(cleaned) > maximum:
        raise TournamentInputError(f"{label} must be 1-{maximum} characters.")
    return cleaned


def _integer(value: Any, label: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool):
        raise TournamentInputError(f"{label} must be a whole number between {minimum} and {maximum}.")
    if isinstance(value, int):
        parsed = value
    elif isinstance(value, str) and value.isdigit():
        parsed = int(value)
    else:
        raise TournamentInputError(f"{label} must be a whole number between {minimum} and {maximum}.")
    if not minimum <= parsed <= maximum:
        raise TournamentInputError(f"{label} must be between {minimum} and {maximum}.")
    return parsed


def _prizes(value: Any) -> list[int]:
    if value is None:
        return []
    if not isinstance(value, (list, tuple)):
        value = [value]
    if len(value) > MAX_PRIZES:
        raise TournamentInputError(f"Add no more than {MAX_PRIZES} position prizes.")
    return [_integer(item, "Position prize", 0, 1000000) for item in value]


def _safe_int(value: Any, fallback: int) -> int:
    return value if isinstance(value, int) and not isinstance(value, bool) else fallback


def _upload_banner(bucket: Any, tournament_id: str, uploaded: Any) -> tuple[str, Any]:
    filename = secure_filename(uploaded.filename or "")
    content_type = uploaded.mimetype or ""
    extension = MIME_EXTENSIONS.get(content_type)
    if not extension or not filename.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
        raise TournamentInputError("Banner must be a JPG, PNG, or WEBP image.")
    content = uploaded.read(MAX_BANNER_BYTES + 1)
    if not content or len(content) > MAX_BANNER_BYTES:
        raise TournamentInputError("Banner must be 4 MB or smaller.")
    blob = bucket.blob(f"tournament-banners/{tournament_id}/banner{extension}")
    token = secrets.token_urlsafe(32)
    blob.metadata = {"firebaseStorageDownloadTokens": token}
    blob.upload_from_string(content, content_type=content_type)
    bucket_name = current_app.config.get("STORAGE_BUCKET", "").strip()
    url = (
        "https://firebasestorage.googleapis.com/v0/b/"
        f"{quote(bucket_name, safe='')}/o/{quote(blob.name, safe='')}?"
        f"alt=media&token={quote(token, safe='')}"
    )
    return url, blob
