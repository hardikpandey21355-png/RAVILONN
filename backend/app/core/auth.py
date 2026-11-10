from functools import wraps
from typing import Any, Callable, TypeVar, cast

import google.auth.exceptions
from firebase_admin import auth as firebase_auth, exceptions as firebase_exceptions
from flask import current_app, g, jsonify, request

from app.core.firestore import _get_firebase_app


F = TypeVar("F", bound=Callable[..., Any])


def api_error(message: str, status: int) -> tuple[Any, int]:
    return jsonify({"ok": False, "error": message}), status


def held_error() -> tuple[Any, int]:
    return jsonify({"ok": False, "held": True, "error": "Account on hold"}), 403


def maintenance_error(status: dict[str, Any]) -> tuple[Any, int]:
    return jsonify(
        {
            "ok": False,
            "maintenance": True,
            "message": status.get("message", "We will be back shortly."),
            "eta": status.get("eta", ""),
            "error": "The app is under maintenance.",
        }
    ), 503


def _token_failure_reason(error: Exception) -> str:
    message = str(error).lower()
    if 'incorrect "aud"' in message:
        return "audience_mismatch"
    if 'incorrect "iss"' in message:
        return "issuer_mismatch"
    if 'no "kid"' in message:
        return "missing_signing_key_id"
    if "incorrect algorithm" in message:
        return "unsupported_algorithm"
    if "used too early" in message:
        return "token_not_yet_valid"
    if "signature" in message:
        return "invalid_signature"
    if "expired" in message:
        return "expired"
    return "invalid_token"


def bearer_token() -> tuple[str | None, tuple[Any, int] | None]:
    value = request.headers.get("Authorization", "")
    scheme, separator, token = value.partition(" ")
    if not separator or scheme.lower() != "bearer" or not token.strip():
        return None, api_error("Firebase ID token is required.", 401)
    return token.strip(), None


def verified_claims(token: str) -> tuple[dict[str, Any] | None, tuple[Any, int] | None]:
    verifier = current_app.config.get("FIREBASE_TOKEN_VERIFIER")
    try:
        claims = (
            verifier(token)
            if verifier is not None
            else firebase_auth.verify_id_token(
                token,
                app=_get_firebase_app(),
                clock_skew_seconds=60,
            )
        )
    except firebase_auth.ExpiredIdTokenError:
        current_app.logger.warning("Firebase ID token verification rejected an expired token")
        return None, api_error("Firebase ID token is invalid or expired.", 401)
    except firebase_auth.InvalidIdTokenError as error:
        current_app.logger.warning(
            "Firebase ID token verification rejected a token (%s)",
            _token_failure_reason(error),
        )
        return None, api_error("Firebase ID token is invalid or expired.", 401)
    except firebase_auth.CertificateFetchError:
        current_app.logger.exception("Firebase token certificate fetch failed")
        return None, api_error("Authentication service is temporarily unavailable.", 503)
    except firebase_exceptions.FirebaseError as error:
        current_app.logger.error(
            "Firebase token verification failed (%s)", type(error).__name__
        )
        return None, api_error("Authentication service is temporarily unavailable.", 503)
    except ValueError:
        current_app.logger.warning("Firebase ID token verification rejected a malformed token")
        return None, api_error("Firebase ID token is invalid or expired.", 401)
    except google.auth.exceptions.TransportError:
        current_app.logger.exception("Firebase token verification is unavailable")
        return None, api_error("Authentication service is temporarily unavailable.", 503)

    if not isinstance(claims, dict):
        current_app.logger.warning("Firebase ID token verifier returned invalid claims")
        return None, api_error("Firebase ID token is invalid or expired.", 401)
    return claims, None


def firebase_uid(claims: dict[str, Any]) -> str | None:
    uid = claims.get("uid") or claims.get("sub")
    return uid if isinstance(uid, str) and uid else None


def require_auth(function: F) -> F:
    @wraps(function)
    def wrapped(*args: Any, **kwargs: Any) -> Any:
        token, error = bearer_token()
        if error:
            return error
        claims, error = verified_claims(cast(str, token))
        if error:
            return error
        uid = firebase_uid(cast(dict[str, Any], claims))
        if not uid:
            return api_error("Firebase ID token has no user ID.", 401)
        g.uid = uid
        g.claims = claims
        if request.endpoint not in {
            "api.me",
            "api.get_tournaments",
            "api.app_status",
            "api.wallet_payment_status",
            "api.delete_account",
        }:
            from app.services.settings_service import get_settings, maintenance_info

            maintenance = maintenance_info(get_settings())
            if maintenance["on"]:
                return maintenance_error(maintenance)
        return function(*args, **kwargs)

    return cast(F, wrapped)


def require_admin(function: F) -> F:
    @wraps(function)
    def wrapped(*args: Any, **kwargs: Any) -> Any:
        token, error = bearer_token()
        if error:
            return error
        claims, error = verified_claims(cast(str, token))
        if error:
            return error
        if not isinstance(claims, dict) or claims.get("admin") is not True:
            return api_error("Admin access required.", 403)
        g.claims = claims
        g.uid = firebase_uid(claims)
        return function(*args, **kwargs)

    return cast(F, wrapped)
