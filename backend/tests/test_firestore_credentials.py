import json
import unittest
from unittest.mock import patch

from app import create_app
from app.core.firestore import _get_firebase_app


class FirebaseCredentialsTests(unittest.TestCase):
    def test_service_account_json_environment_value_initializes_firebase(self) -> None:
        service_account = {
            "type": "service_account",
            "project_id": "ravilon-19a47",
            "private_key": "test-key",
            "client_email": "test@example.com",
        }
        app = create_app(
            {
                "FIREBASE_PROJECT_ID": "ravilon-19a47",
                "FIREBASE_SERVICE_ACCOUNT_JSON": json.dumps(service_account),
            }
        )
        certificate = object()
        firebase_app = object()

        with (
            app.app_context(),
            patch("app.core.firestore.firebase_admin.get_app", side_effect=ValueError),
            patch(
                "app.core.firestore.credentials.Certificate",
                return_value=certificate,
            ) as make_certificate,
            patch(
                "app.core.firestore.firebase_admin.initialize_app",
                return_value=firebase_app,
            ) as initialize_app,
        ):
            result = _get_firebase_app()

        self.assertIs(result, firebase_app)
        make_certificate.assert_called_once_with(service_account)
        initialize_app.assert_called_once_with(
            credential=certificate,
            options={"projectId": "ravilon-19a47"},
        )

    def test_invalid_service_account_json_fails_with_safe_error(self) -> None:
        app = create_app({"FIREBASE_SERVICE_ACCOUNT_JSON": "not-json"})

        with (
            app.app_context(),
            patch("app.core.firestore.firebase_admin.get_app", side_effect=ValueError),
        ):
            with self.assertRaisesRegex(
                ValueError,
                "FIREBASE_SERVICE_ACCOUNT_JSON must contain valid JSON",
            ):
                _get_firebase_app()


if __name__ == "__main__":
    unittest.main()
