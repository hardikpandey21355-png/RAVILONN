import unittest
from unittest.mock import MagicMock, patch

from app.services import admin_service


class AdminWithdrawalTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db = MagicMock()
        self.tx = MagicMock()
        self.withdrawal_ref = MagicMock()
        self.withdrawal_ref.id = "withdrawal-1"
        self.withdrawal_ref.get.return_value.exists = True
        self.withdrawal_ref.get.return_value.to_dict.return_value = {
            "uid": "player-1",
            "amount": 75,
            "status": "pending",
            "transactionId": "ledger-1",
        }
        self.user_ref = MagicMock()
        self.user_ref.get.return_value.exists = True
        self.ledger_ref = MagicMock()
        self.ledger_ref.get.return_value.exists = True
        self.ledger_ref.get.return_value.to_dict.return_value = {
            "kind": "withdraw",
            "status": "pending",
        }
        self.notification_ref = MagicMock()
        self.notification_ref.id = "notification-1"
        self.audit_ref = MagicMock()
        self.audit_ref.id = "audit-1"

        collections: dict[str, MagicMock] = {}
        documents = {
            "withdrawals": {"withdrawal-1": self.withdrawal_ref},
            "users": {"player-1": self.user_ref},
            "transactions": {"ledger-1": self.ledger_ref},
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

    def test_mark_paid_updates_pending_ledger_and_notifies_player(self) -> None:
        with (
            patch.object(
                admin_service,
                "run_transaction",
                side_effect=self._run_transaction,
            ),
            patch.object(
                admin_service,
                "deliver_to_user",
                return_value="sent",
            ) as deliver,
        ):
            result = admin_service.settle_withdrawal(
                "withdrawal-1",
                "paid",
                ref="UPI-REF-1",
                db=self.db,
            )

        updates = {
            call.args[0]: call.args[1]
            for call in self.tx.update.call_args_list
        }
        self.assertEqual(updates[self.withdrawal_ref]["status"], "paid")
        self.assertEqual(updates[self.withdrawal_ref]["payoutRef"], "UPI-REF-1")
        self.assertEqual(updates[self.ledger_ref], {"status": "paid"})
        notice = next(
            call.args[1]
            for call in self.tx.create.call_args_list
            if call.args[0] is self.notification_ref
        )
        self.assertEqual(notice["title"], "Withdrawal successful")
        self.assertIn("₹75", notice["body"])
        self.assertEqual(result["notificationStatus"], "sent")
        deliver.assert_called_once()

    def test_reject_refunds_winnings_and_marks_original_ledger_rejected(self) -> None:
        with (
            patch.object(
                admin_service,
                "run_transaction",
                side_effect=self._run_transaction,
            ),
            patch.object(
                admin_service,
                "apply",
                return_value={"ledgerId": "refund-ledger"},
            ) as apply,
            patch.object(admin_service, "deliver_to_user"),
        ):
            admin_service.settle_withdrawal(
                "withdrawal-1",
                "rejected",
                reason="UPI details issue",
                db=self.db,
            )

        changes = apply.call_args.args[1]
        self.assertEqual(changes["deltas"], {"winnings": 75})
        self.assertEqual(changes["kind"], "withdraw_refund")
        self.assertEqual(changes["ref"], "withdrawal-1")
        updates = {
            call.args[0]: call.args[1]
            for call in self.tx.update.call_args_list
        }
        self.assertEqual(updates[self.withdrawal_ref]["status"], "rejected")
        self.assertEqual(updates[self.ledger_ref], {"status": "rejected"})
        notice = next(
            call.args[1]
            for call in self.tx.create.call_args_list
            if call.args[0] is self.notification_ref
        )
        self.assertIn("returned to your winnings", notice["body"])

    def test_already_settled_request_cannot_be_settled_twice(self) -> None:
        self.withdrawal_ref.get.return_value.to_dict.return_value["status"] = "paid"
        with (
            patch.object(
                admin_service,
                "run_transaction",
                side_effect=self._run_transaction,
            ),
            patch.object(admin_service, "deliver_to_user") as deliver,
        ):
            with self.assertRaisesRegex(
                admin_service.AdminOperationError,
                "already settled",
            ):
                admin_service.settle_withdrawal(
                    "withdrawal-1",
                    "paid",
                    db=self.db,
                )
        deliver.assert_not_called()


if __name__ == "__main__":
    unittest.main()
