import unittest
from datetime import datetime, timezone
from unittest.mock import patch

from app import create_app
from app.services.tranzupi_service import TranzUPIError


class TranzUPIApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.app = create_app(
            {
                "TESTING": True,
                "FIREBASE_TOKEN_VERIFIER": lambda _: {"uid": "player-1"},
            }
        )
        self.client = self.app.test_client()
        self.headers = {"Authorization": "Bearer valid-test-token"}
        self.patches = (
            patch(
                "app.services.settings_service.get_settings",
                return_value={
                    "maintenance": False,
                    "maintenanceMessage": "",
                    "maintenanceEta": "",
                    "minAdd": 5,
                    "maxAdd": 100,
                    "addMoneyMethod": "gateway",
                },
            ),
            patch(
                "app.routes.get_settings",
                return_value={
                    "maintenance": False,
                    "maintenanceMessage": "",
                    "maintenanceEta": "",
                    "minAdd": 5,
                    "maxAdd": 100,
                    "addMoneyMethod": "gateway",
                },
            ),
            patch("app.routes.get_db", return_value=object()),
            patch("app.routes._require_user", return_value=({"isHeld": False}, None)),
        )
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def test_create_payment_order_accepts_five_rupee_minimum(self) -> None:
        with patch(
            "app.routes.create_payment_order",
            return_value={
                "orderId": "RV123",
                "paymentUrl": "https://checkout.tranzupi.com/pay/RV123",
                "status": "pending",
            },
        ) as create_order:
            response = self.client.post(
                "/api/wallet/payment-orders",
                json={"amount": 5},
                headers=self.headers,
            )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json["orderId"], "RV123")
        create_order.assert_called_once()

    def test_create_payment_order_rejects_amount_below_five_rupees(self) -> None:
        with patch("app.routes.create_payment_order") as create_order:
            response = self.client.post(
                "/api/wallet/payment-orders",
                json={"amount": 4},
                headers=self.headers,
            )

        self.assertEqual(response.status_code, 400)
        self.assertIn("between 5 and 100", response.json["error"])
        create_order.assert_not_called()

    def test_create_payment_order_is_blocked_when_add_money_is_off(self) -> None:
        with (
            patch(
                "app.routes.get_settings",
                return_value={"addMoneyMethod": "off", "minAdd": 5, "maxAdd": 100},
            ),
            patch("app.routes.create_payment_order") as create_order,
        ):
            response = self.client.post(
                "/api/wallet/payment-orders",
                json={"amount": 10},
                headers=self.headers,
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json,
            {"ok": False, "error": "Adding money is currently disabled."},
        )
        create_order.assert_not_called()

    def test_create_payment_order_is_blocked_for_legacy_manual_setting(self) -> None:
        with (
            patch(
                "app.routes.get_settings",
                return_value={"addMoneyMethod": "manual", "minAdd": 5, "maxAdd": 100},
            ),
            patch("app.routes.create_payment_order") as create_order,
        ):
            response = self.client.post(
                "/api/wallet/payment-orders",
                json={"amount": 10},
                headers=self.headers,
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json,
            {"ok": False, "error": "Adding money is currently disabled."},
        )
        create_order.assert_not_called()

    def test_manual_deposit_requests_are_blocked_when_method_is_off(self) -> None:
        with patch(
            "app.routes.get_settings",
            return_value={"addMoneyMethod": "off"},
        ):
            response = self.client.post(
                "/api/wallet/deposit-request",
                json={"amount": 10, "utr": "ABC12345"},
                headers=self.headers,
            )

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.json,
            {"ok": False, "error": "Adding money is currently disabled."},
        )

    def test_create_payment_order_rejects_non_integer_amount(self) -> None:
        with patch("app.routes.create_payment_order") as create_order:
            response = self.client.post(
                "/api/wallet/payment-orders",
                json={"amount": 1.5},
                headers=self.headers,
            )

        self.assertEqual(response.status_code, 400)
        create_order.assert_not_called()

    def test_status_returns_paid_wallet_and_formatted_ledger(self) -> None:
        with patch(
            "app.routes.check_payment_order",
            return_value={
                "orderId": "RV123",
                "status": "paid",
                "amount": 1,
                "wallet": {
                    "deposited": 1,
                    "winnings": 0,
                    "bonus": 0,
                    "total": 1,
                },
                "ledger": {
                    "id": "ledger-1",
                    "kind": "added",
                    "title": "Wallet top-up",
                    "amt": 1,
                    "dir": "in",
                    "status": "paid",
                    "createdAt": datetime(2026, 1, 1, tzinfo=timezone.utc),
                },
            },
        ):
            response = self.client.get(
                "/api/wallet/payment-orders/RV123",
                headers=self.headers,
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["status"], "paid")
        self.assertEqual(response.json["wallet"]["deposited"], 1)
        self.assertEqual(response.json["tx"]["id"], "ledger-1")
        self.assertEqual(response.json["tx"]["amt"], "1")

    def test_existing_payment_can_be_confirmed_during_maintenance(self) -> None:
        with (
            patch(
                "app.services.settings_service.get_settings",
                return_value={
                    "maintenance": True,
                    "maintenanceMessage": "Maintenance",
                    "maintenanceEta": "",
                },
            ),
            patch(
                "app.routes.check_payment_order",
                return_value={"orderId": "RV123", "status": "pending", "amount": 1},
            ),
        ):
            response = self.client.get(
                "/api/wallet/payment-orders/RV123",
                headers=self.headers,
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["status"], "pending")

    def test_public_payment_return_verifies_order_and_links_to_app(self) -> None:
        with patch(
            "app.routes.check_payment_order",
            return_value={
                "orderId": "RV123",
                "status": "paid",
                "amount": 1,
                "wallet": {"total": 999999},
            },
        ) as verify_order:
            response = self.client.get("/pay/return?order_id=RV123")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"Payment received", response.data)
        self.assertIn(b"Your wallet is updated.", response.data)
        self.assertIn(b"rivalon://wallet?pay=paid", response.data)
        self.assertIn(b"Continue with RIVALON", response.data)
        self.assertIn(b"background: #080b0a", response.data)
        self.assertIn(b"background: #65d8b5", response.data)
        self.assertNotIn(b"999999", response.data)
        verify_order.assert_called_once_with("RV123")

    def test_public_payment_return_uses_pending_for_temporary_verification_error(self) -> None:
        with patch(
            "app.routes.check_payment_order",
            side_effect=TranzUPIError("Could not verify the payment yet."),
        ):
            response = self.client.get("/pay/return?order_id=RV123")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"Payment is being confirmed", response.data)
        self.assertIn(b"rivalon://wallet?pay=pending", response.data)

    def test_public_payment_return_without_order_shows_failed(self) -> None:
        with patch("app.routes.check_payment_order") as verify_order:
            response = self.client.get("/pay/return")

        self.assertEqual(response.status_code, 200)
        self.assertIn(b"Payment failed", response.data)
        self.assertIn(b"rivalon://wallet?pay=failed", response.data)
        verify_order.assert_not_called()


if __name__ == "__main__":
    unittest.main()
