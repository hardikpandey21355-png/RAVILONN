import unittest
from typing import Any
from unittest.mock import patch

from app import create_app


class AppUpdateApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.app = create_app(
            {
                "TESTING": True,
                "FIREBASE_TOKEN_VERIFIER": self.verify_token,
            }
        )
        self.client = self.app.test_client()

    def verify_token(self, token: str) -> dict[str, Any]:
        if token != "valid-test-token":
            raise ValueError("Invalid token")
        return {"uid": "player-1"}

    def auth_headers(self) -> dict[str, str]:
        return {"Authorization": "Bearer valid-test-token"}

    def test_update_info_requires_authentication(self) -> None:
        response = self.client.get("/api/app-update")

        self.assertEqual(response.status_code, 401)

    def test_app_popup_info_requires_authentication(self) -> None:
        response = self.client.get("/api/app-popup")

        self.assertEqual(response.status_code, 401)

    def test_app_popup_info_returns_disabled_default_and_frequency(self) -> None:
        settings = {
            "appPopupEnabled": False,
            "appPopupTitle": "Ready for your next match?",
            "appPopupMessage": "Join a tournament.",
            "appPopupShowMode": "once",
        }
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.get_settings", return_value=settings),
        ):
            response = self.client.get(
                "/api/app-popup",
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json,
            {
                "ok": True,
                "enabled": False,
                "title": "Ready for your next match?",
                "message": "Join a tournament.",
                "showMode": "once",
            },
        )

    def test_app_popup_info_supports_every_open_mode(self) -> None:
        settings = {
            "appPopupEnabled": True,
            "appPopupTitle": "Tournament update",
            "appPopupMessage": "New matches are available.",
            "appPopupShowMode": "every_open",
        }
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.get_settings", return_value=settings),
        ):
            response = self.client.get(
                "/api/app-popup",
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json["enabled"])
        self.assertEqual(response.json["showMode"], "every_open")

    def test_update_info_honors_disabled_update_settings(self) -> None:
        settings = {
            "maintenance": False,
            "appUpdateEnabled": False,
            "appUpdateForce": False,
            "appLatestVersionCode": 2,
            "appLatestVersionName": "1.1.0",
            "appDownloadUrl": "https://example.com/Ravilon.apk",
            "appUpdateMessage": "An update is available.",
        }
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.get_settings", return_value=settings),
            patch("app.services.settings_service.get_settings", return_value=settings),
        ):
            response = self.client.get(
                "/api/app-update",
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json,
            {
                "ok": True,
                "enabled": False,
                "forceUpdate": False,
                "latestBuildNumber": 9,
                "latestVersionName": "1.1.0",
                "downloadUrl": "https://example.com/Ravilon.apk",
                "message": "An update is available.",
            },
        )

    def test_update_info_can_be_enabled_without_being_mandatory(self) -> None:
        settings = {
            "appUpdateEnabled": True,
            "appUpdateForce": False,
            "appLatestVersionCode": 9,
            "appLatestVersionName": "1.2.0",
            "appDownloadUrl": "https://example.com/Ravilon.apk",
            "appUpdateMessage": "Optional update.",
        }
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.get_settings", return_value=settings),
        ):
            response = self.client.get(
                "/api/app-update",
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json["enabled"])
        self.assertFalse(response.json["forceUpdate"])
        self.assertEqual(response.json["latestBuildNumber"], 9)
        self.assertEqual(response.json["message"], "Optional update.")

    def test_update_info_can_be_enabled_and_mandatory(self) -> None:
        settings = {
            "appUpdateEnabled": True,
            "appUpdateForce": True,
            "appLatestVersionCode": 9,
            "appLatestVersionName": "1.2.0",
            "appDownloadUrl": "https://example.com/Ravilon.apk",
            "appUpdateMessage": "Update required.",
        }
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.get_settings", return_value=settings),
        ):
            response = self.client.get(
                "/api/app-update",
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json["enabled"])
        self.assertTrue(response.json["forceUpdate"])

    def test_update_reward_claim_is_disabled_even_if_saved_setting_enables_it(self) -> None:
        settings = {
            "maintenance": False,
            "appBonusEnabled": True,
            "appBonusBuildNumber": 2,
        }
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.get_settings", return_value=settings),
            patch("app.services.settings_service.get_settings", return_value=settings),
            patch("app.routes.claim_app_update_bonus", return_value=False) as claim,
            patch(
                "app.routes.wallet_for",
                return_value={
                    "deposited": 0,
                    "bonus": 0,
                    "winnings": 0,
                    "total": 0,
                },
            ),
        ):
            response = self.client.post(
                "/api/app-update/claim",
                json={"buildNumber": 2},
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["amount"], 0)
        self.assertFalse(response.json["credited"])
        claim.assert_called_once_with(
            "player-1",
            2,
            campaign_build_number=2,
            enabled=False,
        )

    def test_update_reward_rejects_non_integer_build(self) -> None:
        settings = {"maintenance": False}
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.get_settings", return_value=settings),
            patch("app.services.settings_service.get_settings", return_value=settings),
        ):
            response = self.client.post(
                "/api/app-update/claim",
                json={"buildNumber": True},
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json["error"], "App build number must be an integer.")


if __name__ == "__main__":
    unittest.main()
