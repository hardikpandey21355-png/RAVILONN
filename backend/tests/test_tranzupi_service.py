import unittest
from decimal import Decimal
from unittest.mock import Mock, patch

from app import create_app
from app.services.tranzupi_service import (
    _amount_matches,
    _is_provider_url,
    _payment_state,
    _redirect_url_for_order,
    check_payment_order,
)


class Snapshot:
    def __init__(self, value: dict, exists: bool = True) -> None:
        self.value = value
        self.exists = exists

    def to_dict(self) -> dict:
        return self.value


class Document:
    def __init__(self, value: dict | None) -> None:
        self.value = value

    def get(self, transaction=None) -> Snapshot:
        return Snapshot(self.value or {}, self.value is not None)


class Collection:
    def __init__(self, documents: dict[str, dict]) -> None:
        self.documents = documents

    def document(self, identifier: str) -> Document:
        value = self.documents.get(identifier)
        if value is None:
            return Document(None)
        document = Document(value)
        self.documents[identifier] = document.value
        return document


class MemoryFirestore:
    def __init__(self, orders: dict[str, dict], transactions: dict[str, dict]) -> None:
        self.collections = {
            "paymentOrders": Collection(orders),
            "transactions": Collection(transactions),
        }

    def collection(self, name: str) -> Collection:
        return self.collections[name]


class Transaction:
    def update(self, reference: Document, values: dict) -> None:
        reference.value.update(values)


class TranzUPIServiceTests(unittest.TestCase):
    def test_completed_success_is_paid(self) -> None:
        self.assertEqual(
            _payment_state(
                {
                    "status": "COMPLETED",
                    "result": {
                        "status": "SUCCESS",
                        "orderId": "RV123",
                        "amount": "1.00",
                    },
                }
            )[0],
            "paid",
        )

    def test_pending_payment_is_not_treated_as_success(self) -> None:
        self.assertEqual(
            _payment_state(
                {"status": "PENDING", "result": {"status": "PENDING"}}
            )[0],
            "pending",
        )

    def test_failed_payment_is_not_credited(self) -> None:
        self.assertEqual(
            _payment_state(
                {"status": "COMPLETED", "result": {"status": "FAILED"}}
            )[0],
            "failed",
        )

    def test_amount_comparison_uses_exact_whole_rupees(self) -> None:
        self.assertTrue(_amount_matches("1.00", 1))
        self.assertFalse(_amount_matches("1.01", 1))
        self.assertFalse(_amount_matches(Decimal("NaN"), 1))

    def test_payment_links_must_be_https_tranzupi_urls(self) -> None:
        self.assertTrue(_is_provider_url("https://checkout.tranzupi.com/pay/1"))
        self.assertFalse(_is_provider_url("http://tranzupi.com/pay/1"))
        self.assertFalse(_is_provider_url("https://tranzupi.com.attacker.test/pay"))

    def test_return_url_includes_order_id_without_dropping_existing_parameters(self) -> None:
        redirect_url = _redirect_url_for_order(
            "https://ravilon.example/pay/return?source=tranzupi",
            "RV123",
        )
        self.assertEqual(
            redirect_url,
            "https://ravilon.example/pay/return?source=tranzupi&order_id=RV123",
        )

    def test_confirmed_order_is_credited_only_once(self) -> None:
        db = MemoryFirestore(
            {"RV123": {"uid": "player-1", "amount": 1, "status": "pending"}},
            {
                "ledger-1": {
                    "uid": "player-1",
                    "kind": "added",
                    "title": "Wallet top-up",
                    "amt": 1,
                    "dir": "in",
                    "status": "paid",
                }
            },
        )
        app = create_app(
            {
                "TESTING": True,
                "TRANZUPI_API_KEY": "test-key",
                "TRANZUPI_REDIRECT_URL": "https://ravilon.example/payment-return",
            }
        )
        provider_response = Mock()
        provider_response.json.return_value = {
            "status": "COMPLETED",
            "result": {
                "status": "SUCCESS",
                "orderId": "RV123",
                "amount": "1.00",
            },
        }
        with (
            app.app_context(),
            patch(
                "app.services.tranzupi_service.requests.post",
                return_value=provider_response,
            ) as request_status,
            patch(
                "app.services.tranzupi_service.run_transaction",
                side_effect=lambda _, callback: callback(Transaction()),
            ),
            patch(
                "app.services.tranzupi_service.apply",
                return_value={"ledgerId": "ledger-1"},
            ) as apply_wallet,
            patch(
                "app.services.tranzupi_service.wallet_for",
                return_value={
                    "deposited": 1,
                    "winnings": 0,
                    "bonus": 0,
                    "total": 1,
                },
            ),
        ):
            first = check_payment_order("RV123", uid="player-1", db=db)
            second = check_payment_order("RV123", uid="player-1", db=db)

        self.assertEqual(first["status"], "paid")
        self.assertEqual(second["status"], "paid")
        self.assertEqual(db.collection("paymentOrders").document("RV123").value["status"], "paid")
        apply_wallet.assert_called_once()
        request_status.assert_called_once()


if __name__ == "__main__":
    unittest.main()
