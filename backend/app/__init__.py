import os
from pathlib import Path
from typing import Any

from flask import Flask, current_app, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
from werkzeug.exceptions import InternalServerError, RequestEntityTooLarge

from app.routes import api


DEFAULT_FIREBASE_PROJECT_ID = "ravilon-19a47"
load_dotenv(Path(__file__).resolve().parent.parent / ".env")


def create_app(test_config: dict[str, Any] | None = None) -> Flask:
    application = Flask(__name__)
    application.config.from_mapping(
        FIREBASE_PROJECT_ID=os.environ.get(
            "FIREBASE_PROJECT_ID", DEFAULT_FIREBASE_PROJECT_ID
        ),
        FIREBASE_SERVICE_ACCOUNT_JSON=os.environ.get(
            "FIREBASE_SERVICE_ACCOUNT_JSON", ""
        ),
        FIREBASE_CREDENTIALS=os.environ.get("FIREBASE_CREDENTIALS", ""),
        STORAGE_BUCKET=os.environ.get("STORAGE_BUCKET", ""),
        TRANZUPI_API_KEY=os.environ.get("TRANZUPI_API_KEY", ""),
        TRANZUPI_BASE_URL=os.environ.get(
            "TRANZUPI_BASE_URL", "https://www.tranzupi.com"
        ),
        TRANZUPI_REDIRECT_URL=os.environ.get("TRANZUPI_REDIRECT_URL", ""),
        ALLOWED_ORIGINS=os.environ.get("ALLOWED_ORIGINS", "*"),
        FIREBASE_TOKEN_VERIFIER=None,
        FIRESTORE_CLIENT=None,
        MAX_CONTENT_LENGTH=5 * 1024 * 1024,
    )
    if test_config:
        application.config.update(test_config)

    origins = application.config["ALLOWED_ORIGINS"]
    if isinstance(origins, str) and origins != "*":
        origins = [origin.strip() for origin in origins.split(",") if origin.strip()]
    CORS(
        application,
        resources={r"/api/*": {"origins": origins}},
        allow_headers=["Authorization", "Content-Type"],
        methods=["GET", "POST", "OPTIONS"],
    )

    @application.errorhandler(InternalServerError)
    def handle_internal_error(error: InternalServerError) -> tuple[Any, int]:
        current_app.logger.error(
            "Unhandled backend request error",
            exc_info=error.original_exception or error,
        )
        return jsonify({"ok": False, "error": "Internal server error. Please try again."}), 500

    @application.errorhandler(RequestEntityTooLarge)
    def handle_large_request(_: RequestEntityTooLarge) -> tuple[Any, int]:
        return jsonify({"ok": False, "error": "Screenshot must be 5 MB or smaller."}), 413

    @application.get("/health")
    def health() -> tuple[Any, int]:
        return jsonify({"ok": True, "service": "ravilon-backend"}), 200

    application.register_blueprint(api)
    return application


app = create_app()
