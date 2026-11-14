from datetime import datetime, timezone
from typing import Any
from zoneinfo import ZoneInfo

from firebase_admin import firestore, messaging
from firebase_admin.exceptions import FirebaseError

from app.core.firestore import get_db, run_transaction


IST = ZoneInfo("Asia/Kolkata")
MAX_NOTIFICATION_BATCH = 450


class NotificationInputError(ValueError):
    pass


def validate_content(
    title: Any,
    body: Any,
    link: Any,
) -> tuple[str, str, str]:
    if not isinstance(title, str):
        raise NotificationInputError("Enter a notification title.")
    title = " ".join(title.split())
    if not 3 <= len(title) <= 60:
        raise NotificationInputError("Title must be 3-60 characters.")

    if not isinstance(body, str):
        raise NotificationInputError("Enter a notification message.")
    body = " ".join(body.split())
    if not 3 <= len(body) <= 200:
        raise NotificationInputError("Message must be 3-200 characters.")

    if not isinstance(link, str):
        raise NotificationInputError("Choose a valid in-app destination.")
    link = link.strip()
    if (
        not link.startswith("/")
        or link.startswith("//")
        or len(link) > 100
        or any(ord(char) < 32 for char in link)
    ):
        raise NotificationInputError("Choose a valid in-app destination.")
    return title, body, link


def user_ids(db: Any = None) -> list[str]:
    database = db or get_db()
    return [snapshot.id for snapshot in database.collection("users").stream()]


def enabled_device_count(db: Any = None) -> int:
    database = db or get_db()
    count = 0
    for snapshot in database.collection("users").stream():
        user = snapshot.to_dict() or {}
        settings = user.get("notifSettings")
        settings = settings if isinstance(settings, dict) else {}
        if (
            isinstance(user.get("fcmToken"), str)
            and user["fcmToken"].strip()
            and settings.get("push") is not False
        ):
            count += 1
    return count


def notify_users(
    recipients: list[str],
    title: str,
    body: str,
    link: str,
    *,
    category: str = "admin",
    admin_uid: str = "local-admin",
    db: Any = None,
) -> dict[str, int]:
    database = db or get_db()
    title, body, link = validate_content(title, body, link)
    counts = {"sent": 0, "failed": 0, "no_device": 0, "inbox_saved": 0}
    for uid in dict.fromkeys(recipients):
        status = deliver_to_user(
            uid,
            title,
            body,
            link,
            category=category,
            admin_uid=admin_uid,
            db=database,
        )
        counts["inbox_saved"] += 1
        counts[status] += 1
    return counts


def deliver_to_user(
    uid: str,
    title: str,
    body: str,
    link: str,
    *,
    category: str,
    admin_uid: str,
    notification_id: str | None = None,
    db: Any = None,
) -> str:
    database = db or get_db()
    title, body, link = validate_content(title, body, link)
    user_snapshot = database.collection("users").document(uid).get()
    if not user_snapshot.exists:
        raise NotificationInputError("Notification recipient was not found.")
    user = user_snapshot.to_dict() or {}

    if notification_id is None:
        notification_ref = database.collection("notifications").document()
        notification_id = notification_ref.id
        notification_ref.set(
            {
                "uid": uid,
                "title": title,
                "body": body,
                "link": link,
                "category": category,
                "read": False,
                "createdAt": _server_timestamp(),
            }
        )

    settings = user.get("notifSettings")
    settings = settings if isinstance(settings, dict) else {}
    token = user.get("fcmToken")
    if (
        settings.get("push") is False
        or not isinstance(token, str)
        or not token.strip()
    ):
        status = "no_device"
        error = ""
    else:
        try:
            messaging.send(
                messaging.Message(
                    fid=token.strip(),
                    notification=messaging.Notification(title=title, body=body),
                    data={
                        "link": link,
                        "category": category,
                        "notificationId": notification_id,
                    },
                )
            )
            status = "sent"
            error = ""
        except messaging.UnregisteredError as exception:
            status = "failed"
            error = type(exception).__name__
            _remove_unregistered_fid(database, uid, token.strip())
        except (FirebaseError, ValueError) as exception:
            status = "failed"
            error = type(exception).__name__

    log_ref = database.collection("adminNotificationLogs").document()
    log_ref.set(
        {
            "uid": uid,
            "ign": user.get("ign", ""),
            "gameUid": user.get("gameUid", ""),
            "title": title,
            "body": body,
            "link": link,
            "category": category,
            "notificationId": notification_id,
            "adminUid": admin_uid,
            "pushStatus": status,
            "error": error,
            "createdAt": _server_timestamp(),
        }
    )
    return status


def _remove_unregistered_fid(db: Any, uid: str, fid: str) -> None:
    user_ref = db.collection("users").document(uid)

    def remove_if_unchanged(transaction: Any) -> None:
        snapshot = transaction.get(user_ref)
        user = snapshot.to_dict() or {}
        if user.get("fcmToken") == fid:
            transaction.update(user_ref, {"fcmToken": firestore.DELETE_FIELD})

    run_transaction(db, remove_if_unchanged)


def recent_admin_notifications(limit: int = 100, db: Any = None) -> list[dict[str, Any]]:
    database = db or get_db()
    records = (
        database.collection("adminNotificationLogs")
        .order_by("createdAt", direction="DESCENDING")
        .limit(limit)
        .stream()
    )
    items = []
    for snapshot in records:
        value = snapshot.to_dict() or {}
        items.append(
            {
                "id": snapshot.id,
                "uid": value.get("uid", ""),
                "ign": value.get("ign", ""),
                "game_uid": value.get("gameUid", ""),
                "title": value.get("title", ""),
                "body": value.get("body", ""),
                "push_status": value.get("pushStatus", "failed"),
                "error": value.get("error", ""),
                "when": _format_time(value.get("createdAt")),
                "delivered_ts": "",
                "got": "",
            }
        )
    return items


def clear_admin_notification_history(db: Any = None) -> int:
    database = db or get_db()
    records = list(database.collection("adminNotificationLogs").stream())
    deleted = 0
    for offset in range(0, len(records), MAX_NOTIFICATION_BATCH):
        batch = database.batch()
        chunk = records[offset : offset + MAX_NOTIFICATION_BATCH]
        for snapshot in chunk:
            batch.delete(snapshot.reference)
        batch.commit()
        deleted += len(chunk)
    return deleted


def _server_timestamp() -> Any:
    from firebase_admin import firestore

    return firestore.SERVER_TIMESTAMP


def _format_time(value: Any) -> str:
    if not isinstance(value, datetime):
        return "—"
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(IST).strftime("%d %b, %I:%M %p")
