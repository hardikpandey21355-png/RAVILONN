import unittest
from types import SimpleNamespace
from unittest.mock import patch

from app.services import admin_service


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
        value = self.db.data.get((self.path, self.id))
        return FakeSnapshot(self.id, value, self)

    def collection(self, name):
        return FakeCollection(self.db, f"{self.path}/{self.id}/{name}")


class FakeQuery:
    def __init__(self, collection, filters=()) -> None:
        self.collection = collection
        self.filters = filters

    def where(self, field, _operator, expected):
        return FakeQuery(
            self.collection,
            (*self.filters, (field, expected)),
        )

    def stream(self):
        return [
            snapshot
            for snapshot in self.collection._snapshots()
            if all(
                (snapshot.to_dict() or {}).get(field) == expected
                for field, expected in self.filters
            )
        ]


class FakeCollection:
    def __init__(self, db, path) -> None:
        self.db = db
        self.path = path

    def document(self, identifier=None):
        if identifier is None:
            self.db.next_id += 1
            identifier = f"audit-{self.db.next_id}"
        return FakeDocument(self.db, self.path, identifier)

    def where(self, field, _operator, expected):
        return FakeQuery(self, ((field, expected),))

    def stream(self):
        return self._snapshots()

    def _snapshots(self):
        return [
            FakeSnapshot(identifier, value, FakeDocument(self.db, self.path, identifier))
            for (path, identifier), value in self.db.data.items()
            if path == self.path
        ]


class FakeBatch:
    def __init__(self, db) -> None:
        self.db = db
        self.operations = []

    def delete(self, reference):
        self.operations.append(("delete", reference, None))

    def set(self, reference, value):
        self.operations.append(("set", reference, value))

    def commit(self):
        for operation, reference, value in self.operations:
            key = (reference.path, reference.id)
            if operation == "delete":
                self.db.data.pop(key, None)
            else:
                self.db.data[key] = value


class FakeFirestore:
    def __init__(self, data=None) -> None:
        self.data = data or {}
        self.next_id = 0

    def collection(self, name):
        return FakeCollection(self, name)

    def batch(self):
        return FakeBatch(self)


class AdminIdentityRemovalTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = FakeFirestore(
            {
                ("users", "player-1"): {
                    "name": "Sample",
                    "email": "sample@example.com",
                    "ign": "ShadowX",
                    "gameUid": "1234567890",
                    "upiShot": False,
                },
                ("wallets", "player-1"): {
                    "deposited": 100,
                    "bonus": 10,
                    "winnings": 5,
                },
                ("gameUids", "1234567890"): {"uid": "player-1"},
                ("notifications", "notice-1"): {
                    "uid": "player-1",
                    "title": "Welcome",
                },
                ("adminNotificationLogs", "admin-notice-1"): {
                    "uid": "player-1",
                    "ign": "ShadowX",
                },
                ("users/player-1/appUpdateRewards", "build_2"): {
                    "buildNumber": 2,
                },
                ("withdrawals", "paid-1"): {
                    "uid": "player-1",
                    "status": "paid",
                },
                ("transactions", "transaction-1"): {
                    "uid": "player-1",
                    "amt": 100,
                },
                ("paymentOrders", "order-1"): {
                    "uid": "player-1",
                    "status": "paid",
                },
                ("tournamentEntries", "entry-1"): {
                    "uid": "player-1",
                    "tournamentId": "tournament-1",
                },
            }
        )

    def test_search_matches_player_name_and_reports_wallet(self) -> None:
        with patch.object(admin_service.firebase_auth, "get_user") as get_user:
            matches = admin_service.search_players_for_removal(
                "shadow",
                db=self.db,
            )

        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0]["uid"], "player-1")
        self.assertEqual(matches[0]["email"], "sample@example.com")
        self.assertEqual(matches[0]["total"], 115)
        get_user.assert_not_called()

    def test_search_resolves_firebase_auth_account_by_email_without_profile(self) -> None:
        auth_user = SimpleNamespace(
            uid="auth-only-player",
            email="forgot@example.com",
            display_name="Forgotten Player",
            custom_claims={},
        )
        with patch.object(
            admin_service.firebase_auth,
            "get_user_by_email",
            return_value=auth_user,
        ) as get_user:
            matches = admin_service.search_players_for_removal(
                "forgot@example.com",
                db=self.db,
            )

        self.assertEqual(len(matches), 1)
        self.assertEqual(matches[0]["uid"], "auth-only-player")
        self.assertEqual(matches[0]["name"], "Forgotten Player")
        self.assertEqual(matches[0]["email"], "forgot@example.com")
        self.assertFalse(matches[0]["profile_exists"])
        get_user.assert_called_once_with("forgot@example.com")

    def test_removal_deletes_identity_and_keeps_financial_and_tournament_history(
        self,
    ) -> None:
        auth_user = SimpleNamespace(custom_claims={})
        with (
            patch.object(admin_service.firebase_auth, "get_user", return_value=auth_user),
            patch.object(admin_service.firebase_auth, "delete_user") as delete_user,
        ):
            result = admin_service.remove_player_identity(
                "player-1",
                "player-1",
                db=self.db,
            )

        self.assertTrue(result["authAccountDeleted"])
        self.assertTrue(result["gameUidReleased"])
        self.assertNotIn(("users", "player-1"), self.db.data)
        self.assertNotIn(("wallets", "player-1"), self.db.data)
        self.assertNotIn(("gameUids", "1234567890"), self.db.data)
        self.assertNotIn(("notifications", "notice-1"), self.db.data)
        self.assertNotIn(("adminNotificationLogs", "admin-notice-1"), self.db.data)
        self.assertNotIn(
            ("users/player-1/appUpdateRewards", "build_2"),
            self.db.data,
        )
        for key in (
            ("withdrawals", "paid-1"),
            ("transactions", "transaction-1"),
            ("paymentOrders", "order-1"),
            ("tournamentEntries", "entry-1"),
        ):
            self.assertIn(key, self.db.data)
        self.assertTrue(
            any(path == "auditLogs" for path, _identifier in self.db.data)
        )
        delete_user.assert_called_once_with("player-1")

    def test_pending_withdrawal_blocks_account_removal(self) -> None:
        self.db.data[("withdrawals", "pending-1")] = {
            "uid": "player-1",
            "status": "pending",
        }
        with (
            patch.object(
                admin_service.firebase_auth,
                "get_user",
                return_value=SimpleNamespace(custom_claims={}),
            ),
            patch.object(admin_service.firebase_auth, "delete_user") as delete_user,
        ):
            with self.assertRaisesRegex(
                admin_service.AdminOperationError,
                "pending withdrawals",
            ):
                admin_service.remove_player_identity(
                    "player-1",
                    "player-1",
                    db=self.db,
                )

        delete_user.assert_not_called()

    def test_admin_auth_accounts_are_protected(self) -> None:
        with patch.object(
            admin_service.firebase_auth,
            "get_user",
            return_value=SimpleNamespace(custom_claims={"admin": True}),
        ):
            with self.assertRaisesRegex(
                admin_service.AdminOperationError,
                "Admin accounts",
            ):
                admin_service.remove_player_identity(
                    "player-1",
                    "player-1",
                    db=self.db,
                )

    def test_uid_confirmation_must_match_exactly(self) -> None:
        with self.assertRaisesRegex(
            admin_service.AdminOperationError,
            "exactly",
        ):
            admin_service.remove_player_identity(
                "player-1",
                "player-2",
                db=self.db,
            )


if __name__ == "__main__":
    unittest.main()
