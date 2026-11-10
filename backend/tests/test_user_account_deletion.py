import unittest
from types import SimpleNamespace
from unittest.mock import patch

from firebase_admin import firestore

from app.services import user_service


class FakeSnapshot:
    def __init__(self, identifier, value, reference) -> None:
        self.id = identifier
        self._value = value
        self.reference = reference
        self.exists = value is not None

    def to_dict(self):
        return dict(self._value or {})


class FakeDocument:
    def __init__(self, db, path, identifier) -> None:
        self.db = db
        self.path = path
        self.id = identifier

    def get(self):
        return FakeSnapshot(
            self.id,
            self.db.data.get((self.path, self.id)),
            self,
        )

    def collection(self, name):
        return FakeCollection(self.db, f"{self.path}/{self.id}/{name}")


class FakeQuery:
    def __init__(self, collection, filters=()) -> None:
        self.collection = collection
        self.filters = filters

    def where(self, field, _operator, expected):
        return FakeQuery(self.collection, (*self.filters, (field, expected)))

    def stream(self):
        result = []
        for snapshot in self.collection._snapshots():
            value = snapshot.to_dict()
            if all(
                _field_value(value, field) == expected
                for field, expected in self.filters
            ):
                result.append(snapshot)
        return result


class FakeCollection:
    def __init__(self, db, path) -> None:
        self.db = db
        self.path = path

    def document(self, identifier):
        return FakeDocument(self.db, self.path, identifier)

    def where(self, field, _operator, expected):
        return FakeQuery(self, ((field, expected),))

    def stream(self):
        return self._snapshots()

    def _snapshots(self):
        return [
            FakeSnapshot(
                identifier,
                value,
                FakeDocument(self.db, self.path, identifier),
            )
            for (path, identifier), value in self.db.data.items()
            if path == self.path
        ]


class FakeBatch:
    def __init__(self, db) -> None:
        self.db = db
        self.operations = []

    def delete(self, reference):
        self.operations.append(("delete", reference, None))

    def update(self, reference, values):
        self.operations.append(("update", reference, values))

    def commit(self):
        for operation, reference, values in self.operations:
            key = (reference.path, reference.id)
            if operation == "delete":
                self.db.data.pop(key, None)
            else:
                record = self.db.data[key]
                for field, value in values.items():
                    if type(value).__name__ == "Increment":
                        value = record.get(field, 0) + value.value
                    record[field] = value


class FakeFirestore:
    def __init__(self, data) -> None:
        self.data = data

    def collection(self, name):
        return FakeCollection(self, name)

    def batch(self):
        return FakeBatch(self)


class FakeBlob:
    def __init__(self, name) -> None:
        self.name = name
        self.deleted = False

    def delete(self):
        self.deleted = True


class FakeBucket:
    def __init__(self, blobs) -> None:
        self.blobs = blobs
        self.prefixes = []

    def list_blobs(self, *, prefix):
        self.prefixes.append(prefix)
        return self.blobs


def _field_value(value, field):
    for part in field.split("."):
        if not isinstance(value, dict):
            return None
        value = value.get(part)
    return value


class UserAccountDeletionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = FakeFirestore(
            {
                ("users", "player-1"): {
                    "name": "Sample",
                    "email": "sample@example.com",
                    "gameUid": "1234567890",
                    "upiShot": True,
                },
                ("users/player-1/appUpdateRewards", "build_2"): {
                    "buildNumber": 2,
                },
                ("users/player-1/appBonusCampaigns", "campaign-1"): {
                    "amount": 10,
                },
                ("wallets", "player-1"): {"deposited": 100},
                ("withdrawalLocks", "player-1"): {"withdrawalId": "paid-1"},
                ("gameUids", "1234567890"): {"uid": "player-1"},
                ("notifications", "notice-1"): {"uid": "player-1"},
                ("adminNotificationLogs", "admin-notice-1"): {"uid": "player-1"},
                ("adminWalletCredits", "credit-1"): {"uid": "player-1"},
                ("deposits", "deposit-1"): {"uid": "player-1", "utr": "A123456"},
                ("transactions", "transaction-1"): {"uid": "player-1", "amt": 100},
                ("withdrawals", "paid-1"): {"uid": "player-1", "status": "paid"},
                ("paymentOrders", "order-1"): {"uid": "player-1", "status": "paid"},
                ("tournamentEntries", "entry-1"): {
                    "uid": "player-1",
                    "tournamentId": "tournament-1",
                    "slot": 2,
                },
                ("tournamentResults", "result-1"): {"uid": "player-1"},
                ("tournamentSlotClaims", "tournament-1_2"): {
                    "uid": "player-1",
                    "tournamentId": "tournament-1",
                },
                ("tournaments", "tournament-1"): {"joinedCount": 4},
                ("auditLogs", "audit-target"): {"target": "player-1"},
                ("auditLogs", "audit-actor"): {"adminUid": "player-1"},
                ("auditLogs", "audit-details"): {
                    "details": {"uid": "player-1"},
                },
                ("auditLogs", "unrelated-audit"): {"uid": "another-player"},
            }
        )
        self.blob = FakeBlob("users/player-1/upi.jpg")
        self.bucket = FakeBucket([self.blob])

    def test_deletes_account_data_and_auth_identity(self) -> None:
        with (
            patch.object(
                user_service.firebase_auth,
                "get_user",
                return_value=SimpleNamespace(custom_claims={}),
            ),
            patch.object(user_service.firebase_auth, "delete_user") as delete_user,
        ):
            result = user_service.delete_user_account(
                "player-1",
                db=self.db,
                storage_bucket=self.bucket,
            )

        self.assertTrue(self.blob.deleted)
        self.assertEqual(self.bucket.prefixes, ["users/player-1/"])
        self.assertGreaterEqual(result["documentsDeleted"], 14)
        self.assertEqual(result["filesDeleted"], 1)
        self.assertEqual(
            self.db.data[("tournaments", "tournament-1")]["joinedCount"],
            3,
        )
        self.assertEqual(
            self.db.data,
            {
                ("tournaments", "tournament-1"): {
                    "joinedCount": 3,
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
                ("auditLogs", "unrelated-audit"): {"uid": "another-player"},
            },
        )
        delete_user.assert_called_once_with("player-1")

    def test_pending_withdrawal_blocks_all_deletion(self) -> None:
        self.db.data[("withdrawals", "pending-1")] = {
            "uid": "player-1",
            "status": "pending",
        }
        with (
            patch.object(
                user_service.firebase_auth,
                "get_user",
                return_value=SimpleNamespace(custom_claims={}),
            ),
            patch.object(user_service.firebase_auth, "delete_user") as delete_user,
        ):
            with self.assertRaises(user_service.AccountDeletionError):
                user_service.delete_user_account(
                    "player-1",
                    db=self.db,
                    storage_bucket=self.bucket,
                )

        self.assertFalse(self.blob.deleted)
        self.assertIn(("users", "player-1"), self.db.data)
        delete_user.assert_not_called()

    def test_admin_account_cannot_be_deleted_from_player_endpoint(self) -> None:
        with (
            patch.object(
                user_service.firebase_auth,
                "get_user",
                return_value=SimpleNamespace(custom_claims={"admin": True}),
            ),
            patch.object(user_service.firebase_auth, "delete_user") as delete_user,
        ):
            with self.assertRaises(
                user_service.AdminAccountDeletionNotAllowed
            ):
                user_service.delete_user_account(
                    "player-1",
                    db=self.db,
                    storage_bucket=self.bucket,
                )

        self.assertFalse(self.blob.deleted)
        self.assertIn(("users", "player-1"), self.db.data)
        delete_user.assert_not_called()
