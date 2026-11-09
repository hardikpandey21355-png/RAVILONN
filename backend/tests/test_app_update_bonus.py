import unittest
from unittest.mock import ANY, MagicMock, patch

from app.services.wallet_service import claim_app_update_bonus


class AppUpdateBonusTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        self.claim_ref = MagicMock()
        (
            self.db.collection.return_value.document.return_value.collection
            .return_value.document.return_value
        ) = self.claim_ref
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


if __name__ == "__main__":
    unittest.main()
