import unittest
from unittest.mock import ANY, MagicMock, patch

from app.services.wallet_service import (
    claim_app_update_bonus,
    migrate_app_update_bonus_to_deposit,
)


class AppUpdateBonusTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        self.claim_ref = MagicMock()
        users_collection = MagicMock()
        wallets_collection = MagicMock()
        user_ref = MagicMock()
        rewards_collection = MagicMock()
        wallet_ref = MagicMock()
        self.db.collection.side_effect = lambda name: {
            "users": users_collection,
            "wallets": wallets_collection,
        }[name]
        users_collection.document.return_value = user_ref
        user_ref.collection.return_value = rewards_collection
        rewards_collection.document.return_value = self.claim_ref
        wallets_collection.document.return_value = wallet_ref
        self.wallet_ref = wallet_ref
        self.transaction = MagicMock()

    def test_bonus_is_granted_once_per_user_and_campaign(self) -> None:
        self.claim_ref.get.return_value.exists = False

        with (
            patch(
                "app.services.wallet_service.run_transaction",
                side_effect=lambda _db, operation: operation(self.transaction),
            ),
            patch("app.services.wallet_service._ensure_not_held"),
            patch("app.services.wallet_service.apply") as apply,
        ):
            credited = claim_app_update_bonus(
                "player-1",
                2,
                campaign_build_number=2,
                enabled=True,
                db=self.db,
            )

        self.assertTrue(credited)
        apply.assert_called_once()
        self.transaction.create.assert_called_once_with(
            self.claim_ref,
            {
                "buildNumber": 2,
                "creditBucket": "deposited",
                "createdAt": ANY,
            },
        )

    def test_existing_claim_does_not_credit_again(self) -> None:
        self.claim_ref.get.return_value.exists = True

        with (
            patch(
                "app.services.wallet_service.run_transaction",
                side_effect=lambda _db, operation: operation(self.transaction),
            ),
            patch("app.services.wallet_service.apply") as apply,
        ):
            credited = claim_app_update_bonus(
                "player-1",
                2,
                campaign_build_number=2,
                enabled=True,
                db=self.db,
            )

        self.assertFalse(credited)
        apply.assert_not_called()
        self.transaction.create.assert_not_called()

    def test_old_build_and_disabled_campaign_are_not_eligible(self) -> None:
        self.assertFalse(
            claim_app_update_bonus(
                "player-1",
                1,
                campaign_build_number=2,
                enabled=True,
                db=self.db,
            )
        )
        self.assertFalse(
            claim_app_update_bonus(
                "player-1",
                2,
                campaign_build_number=2,
                enabled=False,
                db=self.db,
            )
        )
        self.db.collection.assert_not_called()

    def test_existing_bonus_is_moved_to_deposit_without_changing_total(self) -> None:
        self.claim_ref.get.return_value.exists = True
        self.claim_ref.get.return_value.to_dict.return_value = {"buildNumber": 2}
        wallet_snapshot = MagicMock()
        wallet_snapshot.exists = True
        wallet_snapshot.to_dict.return_value = {"deposited": 50, "bonus": 10}
        self.wallet_ref.get.return_value = wallet_snapshot

        with (
            patch(
                "app.services.wallet_service.run_transaction",
                side_effect=lambda _db, operation: operation(self.transaction),
            ),
            patch("app.services.wallet_service._ensure_not_held"),
            patch("app.services.wallet_service.apply") as apply,
        ):
            moved = migrate_app_update_bonus_to_deposit(
                "player-1",
                campaign_build_number=2,
                db=self.db,
            )

        self.assertEqual(moved, 10)
        self.assertEqual(
            apply.call_args.args[1]["deltas"],
            {"bonus": -10, "deposited": 10},
        )
        self.transaction.update.assert_called_once_with(
            self.claim_ref,
            {
                "creditBucket": "deposited",
                "depositMigrationAmount": 10,
                "depositMigratedAt": ANY,
            },
        )

    def test_existing_bonus_migration_only_moves_available_balance(self) -> None:
        self.claim_ref.get.return_value.exists = True
        self.claim_ref.get.return_value.to_dict.return_value = {"buildNumber": 2}
        wallet_snapshot = MagicMock()
        wallet_snapshot.exists = True
        wallet_snapshot.to_dict.return_value = {"deposited": 50, "bonus": 4}
        self.wallet_ref.get.return_value = wallet_snapshot

        with (
            patch(
                "app.services.wallet_service.run_transaction",
                side_effect=lambda _db, operation: operation(self.transaction),
            ),
            patch("app.services.wallet_service._ensure_not_held"),
            patch("app.services.wallet_service.apply") as apply,
        ):
            moved = migrate_app_update_bonus_to_deposit(
                "player-1",
                campaign_build_number=2,
                db=self.db,
            )

        self.assertEqual(moved, 4)
        self.assertEqual(
            apply.call_args.args[1]["deltas"],
            {"bonus": -4, "deposited": 4},
        )

    def test_existing_bonus_migration_is_idempotent(self) -> None:
        self.claim_ref.get.return_value.exists = True
        self.claim_ref.get.return_value.to_dict.return_value = {
            "buildNumber": 2,
            "creditBucket": "deposited",
            "depositMigratedAt": object(),
        }

        with (
            patch(
                "app.services.wallet_service.run_transaction",
                side_effect=lambda _db, operation: operation(self.transaction),
            ),
            patch("app.services.wallet_service.apply") as apply,
        ):
            moved = migrate_app_update_bonus_to_deposit(
                "player-1",
                campaign_build_number=2,
                db=self.db,
            )

        self.assertEqual(moved, 0)
        apply.assert_not_called()


if __name__ == "__main__":
    unittest.main()
