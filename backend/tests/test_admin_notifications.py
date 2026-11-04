import unittest
from unittest.mock import MagicMock, patch

from app.services import admin_service


class AdminNotificationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        self.tx = MagicMock()
        self.user_ref = MagicMock()
        self.user_ref.get.return_value.exists = True
        self.user_ref.get.return_value.to_dict.return_value = {
            "isHeld": False,
            "is_held": False,
        }
        self.notification_ref = MagicMock()
        self.notification_ref.id = "notice-1"
        self.audit_ref = MagicMock()
        self.audit_ref.id = "audit-1"
        self.credit_ref = MagicMock()
        self.credit_ref.id = "credit-1"

        def collection(name: str) -> MagicMock:
            result = MagicMock()
            result.document.return_value = {
                "users": self.user_ref,
                "notifications": self.notification_ref,
                "auditLogs": self.audit_ref,
                "adminWalletCredits": self.credit_ref,
            }.get(name, MagicMock())
            return result

        self.db.collection.side_effect = collection

    def _run_transaction(self, _db, operation) -> None:
        operation(self.tx)

    def test_holding_account_creates_private_notice_and_pushes_to_that_user(self) -> None:
        with (
            patch.object(admin_service, "run_transaction", side_effect=self._run_transaction),
            patch.object(admin_service, "deliver_to_user") as deliver,
        ):
            admin_service.set_account_hold(
                "player-1",
                True,
                reason="security review",
                db=self.db,
            )

        notice = self.tx.create.call_args_list[0].args[1]
        self.assertEqual(notice["uid"], "player-1")
        self.assertEqual(notice["category"], "account_hold")
        self.assertIn("security review", notice["body"].lower())
        deliver.assert_called_once()
        self.assertEqual(deliver.call_args.args[0], "player-1")
        self.assertEqual(deliver.call_args.kwargs["notification_id"], "notice-1")

    def test_wallet_credit_notice_is_professional_and_push_is_attempted(self) -> None:
        expected_wallet = {
            "deposited": 50,
            "bonus": 0,
            "winnings": 0,
            "total": 50,
            "ledgerId": "ledger-1",
        }
        with (
            patch.object(admin_service, "run_transaction", side_effect=self._run_transaction),
            patch.object(admin_service, "apply", return_value=expected_wallet),
            patch.object(admin_service, "deliver_to_user") as deliver,
        ):
            result = admin_service.credit_wallet(
                "player-1",
                50,
                "deposited",
                "payment correction",
                db=self.db,
            )

        self.assertEqual(result["total"], 50)
        notice = next(
            call.args[1]
            for call in self.tx.create.call_args_list
            if call.args[0] is self.notification_ref
        )
        self.assertEqual(notice["category"], "wallet_credit")
        self.assertIn("We apologize", notice["body"])
        self.assertIn("₹50", notice["body"])
        deliver.assert_called_once()
        self.assertEqual(deliver.call_args.args[0], "player-1")

    def test_maintenance_enable_notifies_all_users_only_on_transition(self) -> None:
        with (
            patch.object(
                admin_service,
                "get_settings",
                return_value={"maintenance": False},
            ),
            patch.object(
                admin_service,
                "save_maintenance",
                return_value={
                    "maintenance": True,
                    "maintenanceMessage": "Back soon",
                    "maintenanceEta": "10 minutes",
                },
            ),
            patch.object(admin_service, "user_ids", return_value=["p1", "p2"]),
            patch.object(admin_service, "notify_users") as notify,
        ):
            result = admin_service.update_maintenance(
                True,
                "Back soon",
                "10 minutes",
                db=self.db,
            )

        self.assertEqual(result["notificationCounts"], notify.return_value)
        args = notify.call_args.args
        self.assertEqual(args[0], ["p1", "p2"])
        self.assertEqual(args[2], (
            "RIVALON is temporarily under maintenance. Our team is working to "
            "restore service as soon as possible. Please check back shortly. "
            "We currently expect service to return: 10 minutes."
        ))
        self.assertEqual(args[3], "/")


if __name__ == "__main__":
    unittest.main()
