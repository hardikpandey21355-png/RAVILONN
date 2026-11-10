import unittest
from typing import Any
from unittest.mock import patch

from firebase_admin import firestore

from app import create_app
from app.routes import _format_rupees
from app.services.user_service import AccountOnHold


class Snapshot:
    def __init__(self, value: dict[str, Any], exists: bool = True) -> None:
        self._value = value
        self.exists = exists

    def to_dict(self) -> dict[str, Any]:
        return self._value


class Document:
    def __init__(self, value: dict[str, Any]) -> None:
        self.value = value

    def get(self) -> Snapshot:
        return Snapshot(self.value)


class Collection:
    def __init__(self, value: dict[str, Any]) -> None:
        self.value = value

    def document(self, _: str) -> Document:
        return Document(self.value)


class FakeFirestore:
    def __init__(self, user: dict[str, Any]) -> None:
        self.user = user

    def collection(self, name: str) -> Collection:
        if name == "users":
            return Collection(self.user)
        raise AssertionError(f"Unexpected collection: {name}")


class AuthApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.claims: dict[str, Any] = {
            "uid": "firebase-user-1",
            "name": "Test Player",
            "email": "player@example.com",
            "picture": "https://example.com/avatar.png",
        }
        self.app = create_app(
            {
                "TESTING": True,
                "FIREBASE_TOKEN_VERIFIER": self.verify_token,
                "ALLOWED_ORIGINS": "*",
            }
        )
        self.client = self.app.test_client()

    def verify_token(self, token: str) -> dict[str, Any]:
        if token != "valid-test-token":
            raise ValueError("Invalid token")
        return self.claims

    def auth_headers(self) -> dict[str, str]:
        return {"Authorization": "Bearer valid-test-token"}

    def test_login_preserves_identity_and_returns_wallet_metadata(self) -> None:
        response_body = {
            "ok": True,
            "user": {
                "uid": "firebase-user-1",
                "name": "Test Player",
                "email": "player@example.com",
                "picture": "https://example.com/avatar.png",
                "ign": "",
                "gameUid": "",
                "upi": "",
                "hasUpiShot": False,
            },
            "wallet": {"deposited": 0, "winnings": 0, "bonus": 0, "total": 0},
            "gameOk": False,
            "hasUpi": False,
            "dailyLeft": 100,
            "paymentMethod": "gateway",
            "limits": {
                "minAdd": 5,
                "maxAdd": 100,
                "minWithdraw": 20,
                "dailyLimit": 100,
            },
        }
        with (
            patch("app.routes.get_or_create_user", return_value=response_body["user"]),
            patch("app.routes._session_response", return_value=response_body),
        ):
            response = self.client.post(
                "/api/auth/login",
                json={"idToken": "valid-test-token"},
                headers=self.auth_headers(),
            )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json, response_body)

    def test_login_uses_firebase_admin_token_verifier(self) -> None:
        firebase_app = object()
        claims = {
            "uid": "firebase-user-1",
            "email": "player@example.com",
        }
        self.app.config["FIREBASE_TOKEN_VERIFIER"] = None

        with (
            patch("app.core.auth._get_firebase_app", return_value=firebase_app),
            patch(
                "app.core.auth.firebase_auth.verify_id_token",
                return_value=claims,
            ) as verify_token,
            patch("app.routes.get_or_create_user", return_value={"uid": "firebase-user-1"}),
            patch(
                "app.routes._session_response",
                return_value={"ok": True, "user": {"uid": "firebase-user-1"}, "wallet": {}},
            ),
        ):
            response = self.client.post(
                "/api/auth/login",
                json={"idToken": "valid-test-token"},
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        verify_token.assert_called_once_with(
            "valid-test-token",
            app=firebase_app,
            clock_skew_seconds=60,
        )

    def test_expired_firebase_token_returns_authentication_error(self) -> None:
        from firebase_admin import auth as firebase_auth

        self.app.config["FIREBASE_TOKEN_VERIFIER"] = None
        with patch(
            "app.core.auth.firebase_auth.verify_id_token",
            side_effect=firebase_auth.ExpiredIdTokenError("expired", None),
        ):
            response = self.client.post(
                "/api/auth/login",
                json={"idToken": "expired-test-token"},
                headers={"Authorization": "Bearer expired-test-token"},
            )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(
            response.json,
            {"ok": False, "error": "Firebase ID token is invalid or expired."},
        )

    def test_login_requires_bearer_token_to_match_body_token(self) -> None:
        response = self.client.post(
            "/api/auth/login",
            json={"idToken": "other-token"},
            headers=self.auth_headers(),
        )
        self.assertEqual(response.status_code, 401)
        self.assertFalse(response.json["ok"])

    def test_login_requires_bearer_header(self) -> None:
        response = self.client.post(
            "/api/auth/login",
            json={"idToken": "valid-test-token"},
        )
        self.assertEqual(response.status_code, 401)
        self.assertFalse(response.json["ok"])

    def test_login_rejects_held_account(self) -> None:
        with patch("app.routes.get_or_create_user", side_effect=AccountOnHold):
            response = self.client.post(
                "/api/auth/login",
                json={"idToken": "valid-test-token"},
                headers=self.auth_headers(),
            )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json, {"ok": False, "held": True, "error": "Account on hold"})

    def test_me_requires_authentication(self) -> None:
        response = self.client.get("/api/me")
        self.assertEqual(response.status_code, 401)
        self.assertFalse(response.json["ok"])

    def test_me_rejects_held_user(self) -> None:
        fake_db = FakeFirestore({"isHeld": True})
        with patch("app.routes.get_db", return_value=fake_db):
            response = self.client.get("/api/me", headers=self.auth_headers())
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json["error"], "Account on hold")
        self.assertTrue(response.json["held"])

    def test_wallet_and_profile_endpoints_require_authentication(self) -> None:
        paths = (
            "/api/wallet",
            "/api/wallet/transactions",
            "/api/profile/game-status",
            "/api/notifications",
            "/api/account/delete",
        )
        for path in paths:
            with self.subTest(path=path):
                response = (
                    self.client.post(path)
                    if path == "/api/account/delete"
                    else self.client.get(path)
                )
                self.assertEqual(response.status_code, 401)
                self.assertFalse(response.json["ok"])

    def test_device_can_unregister_its_notification_registration(self) -> None:
        with patch("app.routes._save_user_fields", return_value=("", 200)) as save:
            response = self.client.post(
                "/api/profile/fcm-token",
                json={"remove": True},
                headers=self.auth_headers(),
            )

        self.assertEqual(response.status_code, 200)
        save.assert_called_once_with({"fcmToken": firestore.DELETE_FIELD})

    def test_invalid_game_uid_is_rejected_before_firestore(self) -> None:
        response = self.client.post(
            "/api/profile/game-id",
            json={"ign": "Player One", "uid": "not-a-number"},
            headers=self.auth_headers(),
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json["error"], "Game UID must contain 8-12 digits.")

    def test_transaction_amount_uses_indian_grouping(self) -> None:
        self.assertEqual(_format_rupees(1250), "1,250")
        self.assertEqual(_format_rupees(1234567), "12,34,567")


if __name__ == "__main__":
    unittest.main()
