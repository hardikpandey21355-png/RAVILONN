from typing import Any
from urllib.parse import urlsplit

from firebase_admin import firestore

from app.core.firestore import get_db


LATEST_APP_BUILD_NUMBER = 9


DEFAULT_SETTINGS = {
    "minAdd": 5,
    "maxAdd": 100,
    "minWithdraw": 20,
    "dailyLimit": 100,
    "addMoneyMethod": "gateway",
    "maintenance": False,
    "maintenanceMessage": "We will be back shortly.",
    "maintenanceEta": "",
    "appUpdateEnabled": True,
    "appUpdateForce": True,
    "appLatestVersionCode": LATEST_APP_BUILD_NUMBER,
    "appLatestVersionName": "1.2.0",
    "appDownloadUrl": "https://rivalon-site.vercel.app/Ravilon.apk",
    "appUpdateMessage": "App use karte rehne ke liye latest update install karein.",
    "appPopupEnabled": False,
    "appPopupTitle": "Ready for your next match?",
    "appPopupMessage": (
        "Explore tournaments, join your squad, and get ready to play. Check out "
        "the latest matches, see the prizes and entry details, and find the event "
        "that suits you. Gather your teammates, choose your slots, and get ready "
        "for your next match. New tournaments are added regularly, so come back "
        "to see what's happening and make your next game count. Find a tournament "
        "that fits your style, invite your friends, and get ready for the next "
        "challenge."
    ),
    "appPopupShowMode": "once",
    "appBonusEnabled": False,
    "appBonusBuildNumber": 2,
}


def get_settings(db: Any = None) -> dict[str, Any]:
    database = db or get_db()
    snapshot = database.collection("settings").document("app").get()
    stored = snapshot.to_dict() if snapshot.exists else {}
    settings = dict(DEFAULT_SETTINGS)
    if stored:
        for key in DEFAULT_SETTINGS:
            if key in stored:
                settings[key] = stored[key]
    return settings


def get_add_money_method(settings: dict[str, Any]) -> str:
    method = settings.get("addMoneyMethod")
    if isinstance(method, str) and method in {"gateway", "off"}:
        return method
    return "off"


def save_add_money_method(
    method: str,
    *,
    updated_by: str = "local-admin",
    db: Any = None,
) -> dict[str, str]:
    if not isinstance(method, str) or method not in {"gateway", "off"}:
        raise ValueError("Choose Gateway or Off.")
    database = db or get_db()
    database.collection("settings").document("app").set(
        {
            "addMoneyMethod": method,
            "updatedBy": updated_by,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    return {"addMoneyMethod": method}


def save_app_update_settings(
    enabled: bool,
    force: bool,
    version_code: int,
    version_name: str,
    download_url: str,
    message: str,
    *,
    updated_by: str = "local-admin",
    db: Any = None,
) -> dict[str, Any]:
    if not isinstance(enabled, bool) or not isinstance(force, bool):
        raise ValueError("Choose valid app update settings.")
    if isinstance(version_code, bool) or not isinstance(version_code, int):
        raise ValueError("Version code must be a whole number.")
    if version_code < 1:
        raise ValueError("Version code must be at least 1.")
    if not isinstance(version_name, str) or not version_name.strip():
        raise ValueError("Enter the version name.")
    if len(version_name.strip()) > 32:
        raise ValueError("Version name must be 32 characters or fewer.")
    if not isinstance(download_url, str) or len(download_url.strip()) > 1000:
        raise ValueError("Enter a valid APK download URL.")
    download_url = download_url.strip()
    if enabled:
        parsed_url = urlsplit(download_url)
        if (
            parsed_url.scheme != "https"
            or not parsed_url.hostname
            or parsed_url.username is not None
            or parsed_url.password is not None
        ):
            raise ValueError("Enabled updates require a valid HTTPS APK URL.")
    if not isinstance(message, str) or len(message.strip()) > 200:
        raise ValueError("Update message must be 200 characters or fewer.")

    settings = {
        "appUpdateEnabled": enabled,
        "appUpdateForce": force and enabled,
        "appLatestVersionCode": version_code,
        "appLatestVersionName": version_name.strip(),
        "appDownloadUrl": download_url,
        "appUpdateMessage": message.strip(),
    }
    database = db or get_db()
    database.collection("settings").document("app").set(
        {
            **settings,
            "updatedBy": updated_by,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    return settings


def save_app_popup_settings(
    enabled: bool,
    title: str,
    message: str,
    show_mode: str,
    *,
    updated_by: str = "local-admin",
    db: Any = None,
) -> dict[str, Any]:
    if not isinstance(enabled, bool):
        raise ValueError("Choose whether the pop-up is enabled.")
    if not isinstance(title, str) or not isinstance(message, str):
        raise ValueError("Enter a valid pop-up title and message.")
    title = title.strip()
    message = message.strip()
    if not title or len(title) > 80:
        raise ValueError("Title must be between 1 and 80 characters.")
    if not message or len(message) > 2000:
        raise ValueError("Message must be between 1 and 2,000 characters.")
    if not isinstance(show_mode, str) or show_mode not in {"once", "every_open"}:
        raise ValueError("Choose once or every app open.")

    settings = {
        "appPopupEnabled": enabled,
        "appPopupTitle": title,
        "appPopupMessage": message,
        "appPopupShowMode": show_mode,
    }
    database = db or get_db()
    database.collection("settings").document("app").set(
        {
            **settings,
            "updatedBy": updated_by,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    return settings


def save_maintenance(
    enabled: bool,
    message: str,
    eta: str,
    *,
    updated_by: str,
    db: Any = None,
) -> dict[str, Any]:
    database = db or get_db()
    settings = {
        "maintenance": enabled,
        "maintenanceMessage": message,
        "maintenanceEta": eta,
    }
    database.collection("settings").document("app").set(
        {
            **settings,
            "updatedBy": updated_by,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    return settings


def maintenance_info(settings: dict[str, Any]) -> dict[str, Any]:
    return {
        "on": settings.get("maintenance") is True,
        "message": settings.get(
            "maintenanceMessage", "We will be back shortly."
        ),
        "eta": settings.get("maintenanceEta", ""),
    }
