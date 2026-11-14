import unittest
from unittest.mock import MagicMock, patch

from app.services.settings_service import (
    DEFAULT_SETTINGS,
    get_add_money_method,
    get_settings,
    save_app_popup_settings,
    save_app_update_settings,
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

    def test_save_app_update_settings_merges_without_requiring_release(self) -> None:
        db = MagicMock()
        timestamp = object()

        with patch(
            "app.services.settings_service.firestore.SERVER_TIMESTAMP",
            timestamp,
        ):
            result = save_app_update_settings(
                False,
                True,
                8,
                "1.1.0",
                "https://example.com/Ravilon.apk",
                "USB test only.",
                updated_by="admin-1",
                db=db,
            )

        self.assertEqual(
            result,
            {
                "appUpdateEnabled": False,
                "appUpdateForce": False,
                "appLatestVersionCode": 8,
                "appLatestVersionName": "1.1.0",
                "appDownloadUrl": "https://example.com/Ravilon.apk",
                "appUpdateMessage": "USB test only.",
            },
        )
        db.collection.return_value.document.return_value.set.assert_called_once_with(
            {
                **result,
                "updatedBy": "admin-1",
                "updatedAt": timestamp,
            },
            merge=True,
        )

    def test_save_enabled_app_update_requires_https_url_and_valid_version(self) -> None:
        invalid_settings = (
            (True, True, 9, "1.2.0", "http://example.com/app.apk", ""),
            (True, True, 9, "1.2.0", "https://user@example.com/app.apk", ""),
            (True, True, 0, "1.2.0", "https://example.com/app.apk", ""),
            (True, True, 9, "", "https://example.com/app.apk", ""),
        )
        for values in invalid_settings:
            with self.subTest(settings=values):
                with self.assertRaises(ValueError):
                    save_app_update_settings(*values, db=MagicMock())

    def test_save_app_popup_settings_merges_without_enabling_by_default(self) -> None:
        db = MagicMock()
        timestamp = object()

        with patch(
            "app.services.settings_service.firestore.SERVER_TIMESTAMP",
            timestamp,
        ):
            result = save_app_popup_settings(
                True,
                " New message ",
                " Join a tournament today. ",
                "every_open",
                updated_by="admin-1",
                db=db,
            )

        expected = {
            "appPopupEnabled": True,
            "appPopupTitle": "New message",
            "appPopupMessage": "Join a tournament today.",
            "appPopupShowMode": "every_open",
        }
        self.assertEqual(result, expected)
        db.collection.return_value.document.return_value.set.assert_called_once_with(
            {
                **expected,
                "updatedBy": "admin-1",
                "updatedAt": timestamp,
            },
            merge=True,
        )
        self.assertFalse(DEFAULT_SETTINGS["appPopupEnabled"])

    def test_save_app_popup_settings_rejects_invalid_values(self) -> None:
        invalid_settings = (
            ("true", "Title", "Message", "once"),
            (True, "", "Message", "once"),
            (True, "Title", "", "once"),
            (True, "x" * 81, "Message", "once"),
            (True, "Title", "x" * 2001, "once"),
            (True, "Title", "Message", {}),
        )
        for values in invalid_settings:
            with self.subTest(settings=values):
                with self.assertRaises(ValueError):
                    save_app_popup_settings(*values, db=MagicMock())


if __name__ == "__main__":
    unittest.main()
