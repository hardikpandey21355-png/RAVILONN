import unittest
from unittest.mock import MagicMock, patch

from app.services.settings_service import (
    DEFAULT_SETTINGS,
    get_add_money_method,
    get_settings,
    save_add_money_method,
)


class SettingsServiceTests(unittest.TestCase):
    def test_missing_settings_document_uses_gateway_default(self) -> None:
        db = MagicMock()
        db.collection.return_value.document.return_value.get.return_value.exists = False

        settings = get_settings(db)

        self.assertEqual(settings["addMoneyMethod"], "gateway")
        self.assertEqual(get_add_money_method(settings), "gateway")
        self.assertEqual(settings["minAdd"], DEFAULT_SETTINGS["minAdd"])

    def test_invalid_stored_payment_method_fails_closed(self) -> None:
        self.assertEqual(get_add_money_method({"addMoneyMethod": {"unexpected": True}}), "off")
        self.assertEqual(get_add_money_method({"addMoneyMethod": "unexpected"}), "off")
        self.assertEqual(get_add_money_method({"addMoneyMethod": "manual"}), "off")

    def test_save_method_merges_into_app_settings(self) -> None:
        db = MagicMock()
        timestamp = object()

        with patch(
            "app.services.settings_service.firestore.SERVER_TIMESTAMP",
            timestamp,
        ):
            result = save_add_money_method(
                "off",
                updated_by="admin-1",
                db=db,
            )

        self.assertEqual(result, {"addMoneyMethod": "off"})
        db.collection.assert_called_once_with("settings")
        db.collection.return_value.document.assert_called_once_with("app")
        db.collection.return_value.document.return_value.set.assert_called_once_with(
            {
                "addMoneyMethod": "off",
                "updatedBy": "admin-1",
                "updatedAt": timestamp,
            },
            merge=True,
        )

    def test_save_rejects_non_string_and_unknown_methods(self) -> None:
        for invalid_method in (None, {}, "custom", "manual"):
            with self.subTest(method=invalid_method):
                with self.assertRaises(ValueError):
                    save_add_money_method(invalid_method, db=MagicMock())


if __name__ == "__main__":
    unittest.main()
