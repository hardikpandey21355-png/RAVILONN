import unittest
from unittest.mock import patch

from app.services import admin_service


class Snapshot:
    def __init__(self, identifier, data, reference):
        self.id = identifier
        self._data = data
        self.reference = reference
        self.exists = data is not None

    def to_dict(self):
        return dict(self._data or {})


class Document:
    def __init__(self, db, path, identifier):
        self.db = db
        self.path = path
        self.id = identifier

    def get(self, transaction=None):
        return Snapshot(self.id, self.db.data.get((self.path, self.id)), self)

    def collection(self, name):
        return Collection(self.db, f"{self.path}/{self.id}/{name}")


class Collection:
    def __init__(self, db, path):
        self.db = db
        self.path = path

    def document(self, identifier=None):
        if identifier is None:
            self.db.next_id += 1
            identifier = f"audit-{self.db.next_id}"
        return Document(self.db, self.path, identifier)

    def stream(self):
        return [
            Snapshot(identifier, value, Document(self.db, self.path, identifier))
            for (path, identifier), value in self.db.data.items()
            if path == self.path
        ]


class Database:
    def __init__(self, data):
        self.data = data
        self.next_id = 0

    def collection(self, name):
        return Collection(self, name)


class Transaction:
    def __init__(self, db):
        self.db = db

    def update(self, reference, values):
        self.db.data[(reference.path, reference.id)].update(values)

    def create(self, reference, values):
        self.db.data[(reference.path, reference.id)] = values


class AppUpdateRewardRevocationTests(unittest.TestCase):
    def setUp(self):
        self.db = Database(
            {
                ("users", "old-claim"): {},
                ("users/old-claim/appUpdateRewards", "build_2"): {
                    "buildNumber": 2,
                },
                ("wallets", "old-claim"): {
                    "deposited": 100,
                    "bonus": 5,
                    "winnings": 20,
                },
                ("users", "migrated-claim"): {},
                ("users/migrated-claim/appUpdateRewards", "build_2"): {
                    "buildNumber": 2,
                    "creditBucket": "deposited",
                },
                ("wallets", "migrated-claim"): {
                    "deposited": 10,
                    "bonus": 0,
                    "winnings": 0,
                },
                ("users", "spent-claim"): {},
                ("users/spent-claim/appUpdateRewards", "build_2"): {
                    "buildNumber": 2,
                    "creditBucket": "bonus",
                },
                ("wallets", "spent-claim"): {
                    "deposited": 0,
                    "bonus": 0,
                    "winnings": 0,
                },
            }
        )
        self.transaction = Transaction(self.db)
        self.applied = []

    def _apply(self, uid, changes, _transaction):
        self.applied.append((uid, changes))
        wallet = self.db.data[("wallets", uid)]
        for bucket, delta in changes["deltas"].items():
            wallet[bucket] += delta
            self.assertGreaterEqual(wallet[bucket], 0)

    def _run_transaction(self, _db, operation):
        return operation(self.transaction)

    def test_revocation_uses_original_bucket_caps_at_ten_and_is_idempotent(self):
        with (
            patch.object(
                admin_service,
                "run_transaction",
                side_effect=self._run_transaction,
            ),
            patch.object(admin_service, "apply", side_effect=self._apply),
        ):
            result = admin_service.revoke_app_update_bonuses(
                admin_uid="admin-1",
                db=self.db,
            )
            repeated_result = admin_service.revoke_app_update_bonuses(
                admin_uid="admin-1",
                db=self.db,
            )

        self.assertEqual(
            result,
            {
                "accountsProcessed": 3,
                "accountsWithBalance": 2,
                "amountRemoved": 15,
                "amountUnavailable": 15,
            },
        )
        self.assertEqual(
            repeated_result,
            {
                "accountsProcessed": 0,
                "accountsWithBalance": 0,
                "amountRemoved": 0,
                "amountUnavailable": 0,
            },
        )
        self.assertEqual(
            [(uid, change["deltas"]) for uid, change in self.applied],
            [
                ("old-claim", {"bonus": -5}),
                ("migrated-claim", {"deposited": -10}),
            ],
        )
        self.assertEqual(self.db.data[("wallets", "old-claim")]["bonus"], 0)
        self.assertEqual(
            self.db.data[
                ("users/spent-claim/appUpdateRewards", "build_2")
            ]["unavailableAmount"],
            10,
        )
        self.assertEqual(
            len([path for path, _ in self.db.data if path == "auditLogs"]),
            3,
        )

    def test_app_bonus_preview_and_distribution_are_idempotent(self):
        self.db = Database(
            {
                ("users", "already-credited"): {"isHeld": True},
                (
                    "users/already-credited/appBonusCampaigns",
                    "summer-2026",
                ): {"campaignId": "summer-2026", "amount": 20},
                ("wallets", "already-credited"): {"deposited": 20},
                ("users", "new-player"): {},
                ("wallets", "new-player"): {"deposited": 5},
            }
        )
        self.transaction = Transaction(self.db)
        self.applied = []

        with (
            patch.object(
                admin_service,
                "run_transaction",
                side_effect=self._run_transaction,
            ),
            patch.object(admin_service, "apply", side_effect=self._apply),
        ):
            preview = admin_service.preview_app_bonus_distribution(
                " Summer-2026 ",
                20,
                db=self.db,
            )
            result = admin_service.distribute_app_bonus(
                "summer-2026",
                20,
                admin_uid="admin-1",
                db=self.db,
            )
            repeated_result = admin_service.distribute_app_bonus(
                "summer-2026",
                20,
                admin_uid="admin-1",
                db=self.db,
            )

        self.assertEqual(
            preview,
            {
                "campaignId": "summer-2026",
                "amountPerUser": 20,
                "accountCount": 2,
                "alreadyCredited": 1,
                "eligibleCount": 1,
                "estimatedTotal": 20,
            },
        )
        self.assertEqual(result["accountsCredited"], 1)
        self.assertEqual(result["amountCredited"], 20)
        self.assertEqual(repeated_result["accountsCredited"], 0)
        self.assertEqual(repeated_result["accountsAlreadyCredited"], 2)
        self.assertEqual(
            self.applied[0][1]["deltas"],
            {"deposited": 20},
        )
        self.assertEqual(self.db.data[("wallets", "new-player")]["deposited"], 25)
        self.assertEqual(
            self.db.data[
                ("users/new-player/appBonusCampaigns", "summer-2026")
            ]["adminUid"],
            "admin-1",
        )
        self.assertEqual(
            len([path for path, _ in self.db.data if path == "auditLogs"]),
            1,
        )

    def test_app_bonus_rejects_invalid_campaign_and_amount(self):
        for campaign_id, amount in (
            ("../all-users", 10),
            ("summer-2026", 0),
            ("summer-2026", True),
            ("summer-2026", 10001),
        ):
            with self.subTest(campaign_id=campaign_id, amount=amount):
                with self.assertRaises(admin_service.AdminOperationError):
                    admin_service.preview_app_bonus_distribution(
                        campaign_id,
                        amount,
                        db=self.db,
                    )


if __name__ == "__main__":
    unittest.main()
