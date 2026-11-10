from typing import Any

from firebase_admin import firestore

from app.core.firestore import get_db


LATEST_APP_BUILD_NUMBER = 8


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
    "appLatestVersionName": "1.1.0",
    "appDownloadUrl": (
        "https://github.com/hardikpandey21355-png/"
        "Rival-on-website/raw/refs/heads/main/Ravilon.apk"
    ),
    "appUpdateMessage": "App use karte rehne ke liye latest update install karein.",
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
