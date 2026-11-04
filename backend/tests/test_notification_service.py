import unittest
from typing import Any
from unittest.mock import patch

from app.services.notification_service import (
    NotificationInputError,
    enabled_device_count,
    notify_users,
)


class Snapshot:
    def __init__(self, identifier: str, value: dict[str, Any] | None) -> None:
        self.id = identifier
        self.value = value
        self.exists = value is not None
        self.reference = None

    def to_dict(self) -> dict[str, Any]:
        return dict(self.value or {})


class Document:
    def __init__(self, db: "FakeFirestore", collection: str, identifier: str) -> None:
        self.db = db
        self.collection = collection
        self.id = identifier

    def get(self) -> Snapshot:
        snapshot = Snapshot(self.id, self.db.data[self.collection].get(self.id))
        snapshot.reference = self
        return snapshot

    def set(self, value: dict[str, Any]) -> None:
        self.db.data[self.collection][self.id] = dict(value)


class Collection:
    def __init__(self, db: "FakeFirestore", name: str) -> None:
        self.db = db
        self.name = name

    def document(self, identifier: str | None = None) -> Document:
        if identifier is None:
            self.db.next_id += 1
            identifier = f"doc-{self.db.next_id}"
        return Document(self.db, self.name, identifier)

    def stream(self) -> list[Snapshot]:
        results = []
        for identifier, value in self.db.data[self.name].items():
            snapshot = Snapshot(identifier, value)
            snapshot.reference = Document(self.db, self.name, identifier)
            results.append(snapshot)
        return results


class FakeFirestore:
    def __init__(self) -> None:
        self.data: dict[str, dict[str, dict[str, Any]]] = {
            "users": {
                "with-device": {
                    "fcmToken": "token-for-test",
                    "notifSettings": {"push": True},
                    "ign": "Player One",
                    "gameUid": "1234567890",
                },
                "push-disabled": {
                    "fcmToken": "disabled-token",
                    "notifSettings": {"push": False},
                },
            },
            "notifications": {},
            "adminNotificationLogs": {},
        }
        self.next_id = 0

    def collection(self, name: str) -> Collection:
        self.data.setdefault(name, {})
        return Collection(self, name)


class NotificationServiceTests(unittest.TestCase):
    def test_saves_inbox_for_each_target_and_pushes_only_enabled_devices(self) -> None:
        db = FakeFirestore()
        with patch("app.services.notification_service.messaging.send") as send:
            counts = notify_users(
                ["with-device", "push-disabled"],
                "Tournament update",
                "Your match details are ready.",
                "/matches",
                db=db,
            )

        self.assertEqual(
            counts,
            {"sent": 1, "failed": 0, "no_device": 1, "inbox_saved": 2},
        )
        self.assertEqual(send.call_count, 1)
        self.assertEqual(send.call_args.args[0].fid, "token-for-test")
        self.assertEqual(len(db.data["notifications"]), 2)
        self.assertEqual(len(db.data["adminNotificationLogs"]), 2)
        self.assertEqual(enabled_device_count(db), 1)
        self.assertEqual(
            {item["pushStatus"] for item in db.data["adminNotificationLogs"].values()},
            {"sent", "no_device"},
        )

    def test_records_push_failure_without_losing_in_app_notification(self) -> None:
        db = FakeFirestore()
        with patch(
            "app.services.notification_service.messaging.send",
            side_effect=ValueError("Invalid registration token"),
        ):
            counts = notify_users(
                ["with-device"],
                "Account update",
                "Please review your account information.",
                "/profile",
                db=db,
            )

        self.assertEqual(counts["failed"], 1)
        self.assertEqual(len(db.data["notifications"]), 1)
        log = next(iter(db.data["adminNotificationLogs"].values()))
        self.assertEqual(log["pushStatus"], "failed")
        self.assertEqual(log["error"], "ValueError")
        self.assertNotIn("token-for-test", str(log))

    def test_rejects_external_notification_links(self) -> None:
        with self.assertRaisesRegex(NotificationInputError, "destination"):
            notify_users(
                ["with-device"],
                "Account update",
                "Please review your account information.",
                "https://example.com",
                db=FakeFirestore(),
            )


if __name__ == "__main__":
    unittest.main()
