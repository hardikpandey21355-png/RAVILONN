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

    def test_update_info_returns_configured_release(self) -> None:
        settings = {
            "maintenance": False,
            "appUpdateEnabled": True,
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
                "enabled": True,
                "latestBuildNumber": 3,
                "latestVersionName": "1.1.0",
                "downloadUrl": "https://example.com/Ravilon.apk",
                "message": "An update is available.",
            },
        )

    def test_update_reward_is_limited_to_authenticated_user_and_build(self) -> None:
        settings = {
            "maintenance": False,
            "appBonusEnabled": True,
            "appBonusBuildNumber": 2,
        }
        with (
            patch("app.routes._require_user", return_value=({}, None)),
            patch("app.routes.get_settings", return_value=settings),
            patch("app.services.settings_service.get_settings", return_value=settings),
            patch(
                "app.routes.migrate_app_update_bonus_to_deposit",
                return_value=0,
            ) as migrate,
            patch("app.routes.claim_app_update_bonus", return_value=True) as claim,
            patch(
                "app.routes.wallet_for",
                return_value={
                    "deposited": 10,
                    "bonus": 0,
                    "winnings": 0,
                    "total": 10,
                },
            ),
        ):
            response = self.client.post(
                "/api/app-update/claim",
                json={"buildNumber": 2},
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["amount"], 10)
        self.assertEqual(response.json["wallet"]["deposited"], 10)
        self.assertEqual(response.json["migratedToDeposit"], 0)
        migrate.assert_called_once_with("player-1", campaign_build_number=2)
        claim.assert_called_once_with(
            "player-1",
            2,
            campaign_build_number=2,
            enabled=True,
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
