import unittest
from unittest.mock import MagicMock, patch

from app.services import admin_service


class AdminWalletAdjustmentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        self.tx = MagicMock()
        self.user_ref = MagicMock()
        self.user_ref.get.return_value.exists = True
        self.notification_ref = MagicMock()
        self.notification_ref.id = "notice-1"
        self.audit_ref = MagicMock()
        self.audit_ref.id = "audit-1"
        collections: dict[str, MagicMock] = {}
        documents = {
            "users": {"player-1": self.user_ref},
            "notifications": {None: self.notification_ref},
            "auditLogs": {None: self.audit_ref},
        }

        def collection(name: str) -> MagicMock:
            if name not in collections:
                collection_ref = MagicMock()
                collection_ref.document.side_effect = (
                    lambda identifier=None: documents[name][identifier]
                )
                collections[name] = collection_ref
            return collections[name]

        self.db.collection.side_effect = collection

    def _run_transaction(self, _db, operation) -> None:
        operation(self.tx)

    def test_deduction_updates_wallet_ledger_audit_and_notification(self) -> None:
        wallet = {"deposited": 50, "winnings": 20, "bonus": 0, "total": 70, "ledgerId": "ledger-1"}
        with (
            patch.object(admin_service, "run_transaction", side_effect=self._run_transaction),
            patch.object(admin_service, "apply", return_value=wallet) as apply,
            patch.object(admin_service, "deliver_to_user", return_value="sent") as deliver,
        ):
            result = admin_service.deduct_wallet(
                "player-1",
                25,
                "deposited",
                "Suspicious credited amount",
                admin_uid="admin-1",
                db=self.db,
            )

        changes = apply.call_args.args[1]
        self.assertEqual(changes["deltas"], {"deposited": -25})
        self.assertEqual(changes["kind"], "admin_deduction")
        self.assertEqual(changes["dir"], "out")
        self.assertEqual(changes["status"], "paid")
        self.assertEqual(changes["ref"], "audit-1")

        creates = {call.args[0]: call.args[1] for call in self.tx.create.call_args_list}
        notice = creates[self.notification_ref]
        self.assertIn("₹25", notice["body"])
        self.assertIn("deposited balance", notice["body"])
        audit = creates[self.audit_ref]
        self.assertEqual(audit["adminUid"], "admin-1")
        self.assertEqual(audit["action"], "wallet_deduction")
        self.assertEqual(audit["details"]["transactionId"], "ledger-1")
        self.assertEqual(result["notificationStatus"], "sent")
        deliver.assert_called_once()

    def test_deduction_reports_insufficient_balance(self) -> None:
        with (
            patch.object(admin_service, "run_transaction", side_effect=self._run_transaction),
            patch.object(
                admin_service,
                "apply",
                side_effect=admin_service.InsufficientFunds,
            ),
            patch.object(admin_service, "deliver_to_user") as deliver,
        ):
            with self.assertRaisesRegex(
                admin_service.AdminOperationError,
                "exceeds the selected wallet balance",
            ):
                admin_service.deduct_wallet(
                    "player-1",
                    100,
                    "winnings",
                    "Suspicious credited amount",
                    db=self.db,
                )

        deliver.assert_not_called()

    def test_deduction_rejects_invalid_amount_bucket_or_reason(self) -> None:
        cases = (
            (0, "deposited", "Valid reason"),
            (1, "bonus", "Valid reason"),
            (1, "winnings", " "),
        )
        for amount, bucket, reason in cases:
            with self.subTest(amount=amount, bucket=bucket):
                with self.assertRaises(admin_service.AdminOperationError):
                    admin_service.deduct_wallet(
                        "player-1",
                        amount,
                        bucket,
                        reason,
                        db=self.db,
                    )

    def test_player_details_include_account_stats_wallet_and_full_ledger_rows(self) -> None:
        user_snapshot = MagicMock()
        user_snapshot.exists = True
        user_snapshot.to_dict.return_value = {
            "name": "TestPlayer",
            "email": "player@example.com",
            "ign": "Test",
            "gameUid": "1234567890",
            "isHeld": True,
        }
        transaction_snapshot = MagicMock()
        transaction_snapshot.id = "tx-1"
        transaction_snapshot.to_dict.return_value = {
            "kind": "admin_deduction",
            "title": "Suspicious amount adjustment",
            "amt": 25,
            "dir": "out",
            "status": "paid",
            "ref": "audit-1",
        }
        users = MagicMock()
        users.document.return_value.get.return_value = user_snapshot
        transactions = MagicMock()
        transactions.where.return_value.order_by.return_value.stream.return_value = [
            transaction_snapshot
        ]
        self.db.collection.side_effect = lambda name: {
            "users": users,
            "transactions": transactions,
        }[name]
        wallet = {"deposited": 100, "winnings": 50, "bonus": 10, "total": 160}
        stats = {"matches": 4, "wins": 2, "kills": 7, "earned": 300}
        with (
            patch.object(admin_service, "wallet_for", return_value=wallet),
            patch.object(admin_service, "profile_stats", return_value=stats),
        ):
            details = admin_service.player_account_details("player-1", self.db)

        self.assertEqual(details["email"], "player@example.com")
        self.assertEqual(details["uid"], "player-1")
        self.assertEqual(details["wallet"], wallet)
        self.assertEqual(details["stats"], stats)
        self.assertTrue(details["held"])
        self.assertEqual(details["transactions"][0]["id"], "tx-1")
        self.assertEqual(details["transactions"][0]["amount"], 25)
        self.assertEqual(details["transactions"][0]["reference"], "audit-1")


if __name__ == "__main__":
    unittest.main()
