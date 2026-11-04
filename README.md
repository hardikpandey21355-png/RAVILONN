# Ravilon

Private monorepo for the Ravilon player app, Flask API, and Admin panel.

## Components

- `frontend/` — Flutter Android application.
- `backend/` — Flask API and Firestore configuration.
- `ADMIN/` — Flask-based Admin panel; it imports shared modules from `backend/`.

The API and Admin panel are separate web services and should be deployed from
this repository with the repository root as their build context. Keep their
runtime configuration in the hosting provider's secret environment settings;
never commit `.env` files or Firebase service-account keys.

The mobile app must be built with the public HTTPS API URL, for example:

```powershell
cd frontend
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-API-DOMAIN
```

See [backend/README_backend.md](backend/README_backend.md) for API, Firebase,
and payment configuration details.
