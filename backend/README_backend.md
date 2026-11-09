# Ravilon backend

The Flask API authenticates Firebase ID tokens and stores user, wallet, ledger,
profile, notification, and tournament data in Firestore. The backend loads
`backend/.env`; set `FIREBASE_CREDENTIALS` to a service-account JSON path, or
configure Application Default Credentials / `GOOGLE_APPLICATION_CREDENTIALS`.
Set `FIREBASE_PROJECT_ID` to `ravilon-19a47` if using another project
environment. To enable private UPI screenshot uploads, set `STORAGE_BUCKET`.

## Run locally

From `backend/`:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:FIREBASE_PROJECT_ID = "ravilon-19a47"
python run.py
```

No application data is written to SQLite or local files. Firebase ID-token
verification uses Google's public signing keys.

## Deploy the API to Vercel

Import the repository into Vercel and set the project Root Directory to
`backend`. Keep the Flask preset and default build/install settings. Vercel
detects the Flask `app` in `index.py` and installs dependencies from
`requirements.txt`.

Add these environment variables in Vercel Project Settings before deploying:

- `FIREBASE_PROJECT_ID`: `ravilon-19a47`.
- `FIREBASE_SERVICE_ACCOUNT_JSON`: the complete Firebase service-account JSON
  object, pasted as the value. Treat this as a secret; do not commit it or share
  it in chat. The API also supports the existing `FIREBASE_CREDENTIALS` file
  path for local and Render deployments.
- `STORAGE_BUCKET`: set this if the API needs private UPI screenshot or
  tournament banner uploads.
- `TRANZUPI_API_KEY` and `TRANZUPI_REDIRECT_URL`: set these if hosted payments
  are enabled. The redirect URL should use the deployed API's public HTTPS URL.

Deploy, then verify `https://<deployment-domain>/health` returns
`{"ok":true,"service":"ravilon-backend"}`. Test authenticated API endpoints and
payment callbacks before switching the APK's API URL or disabling the Render
service. Update the TranZUPI webhook URL to
`https://<deployment-domain>/api/payments/tranzupi/webhook` when switching.

## Mobile app updates

The authenticated `GET /api/app-update` endpoint provides the latest Android
version and download URL. Builds that include the update checker show an
optional Update / Skip prompt only when the configured version code is newer.
The authenticated `POST /api/app-update/claim` endpoint grants the one-time
₹10 bonus to the bonus wallet bucket for eligible builds. A Firestore
transaction prevents an account from claiming the same campaign twice.

These settings are read from `settings/app` and fall back to the defaults in
`settings_service.py`:

- `appUpdateEnabled`, `appLatestVersionCode`, `appLatestVersionName`,
  `appDownloadUrl`, and `appUpdateMessage` control the update prompt.
- `appBonusEnabled` and `appBonusBuildNumber` control the one-time bonus
  campaign.

Deploy the backend update before distributing the APK. Existing APKs that do
not contain the update checker cannot display the prompt; announce the release
to those users through the Admin Notifications page.

## Endpoints

All `/api` endpoints require a Firebase ID token in the `Authorization: Bearer`
header, except `POST /api/auth/login`, which also requires that same token in
the JSON `idToken` property.

- `POST /api/auth/login`: create/refresh the Firestore user profile; return
  profile, wallet, `hasUpi`, `dailyLeft`, and wallet `limits`.
- `GET /api/me`: return the signed-in user session and wallet summary.
- `GET /api/app-update`: return Android update metadata.
- `POST /api/app-update/claim`: atomically credit the eligible account's
  one-time APK update bonus.
- `GET /api/tournaments`: return scheduled normal and loot tournaments to the
  authenticated player app.
- `GET /api/wallet`: wallet balances, UPI state, today's remaining withdrawal
  allowance, configured limits, and the active `paymentMethod` (`gateway`,
  `manual`, or `off`).
- `GET /api/wallet/transactions?kind=&limit=50`: newest-first user ledger.
- `POST /api/wallet/deposit-request`: request a deposit with `amount` and `utr`.
- `POST /api/wallet/payment-orders`: create a TranZUPI hosted checkout order.
- `GET /api/wallet/payment-orders/<order_id>`: verify an order with TranZUPI
  and credit the wallet exactly once after confirmed success.
- `POST /api/payments/tranzupi/webhook`: provider callback; the callback is only
  a signal to re-check the order directly with TranZUPI.
- `GET /pay/return?order_id=<order_id>`: public payment result page; verifies
  the order server-side and offers a `rivalon://wallet?pay=...` app link.
- `POST /api/wallet/withdraw`: request a winnings withdrawal.
- `POST /api/wallet/winnings-to-deposit`: move winnings into deposited balance.
- `POST /api/profile/game-id`: save IGN and uniquely claim a game UID.
- `POST /api/profile/upi`: multipart form with `upi` and optional `shot`
  (JPG/PNG/WebP, at most 5 MB; uploaded privately when `STORAGE_BUCKET` is set).
- `GET /api/profile/game-status`: report whether the game profile is ready.
- `POST /api/profile/fcm-token`: save the Firebase Messaging installation ID in
  JSON `token`; send `{"remove": true}` to unregister the signed-in device.
- `POST /api/profile/notif-settings`: save JSON booleans `push`, `reminders`,
  and `results`.
- `GET /api/notifications?limit=30`: list the signed-in user's notifications.
- `POST /api/notifications/read-all`: mark that user's notifications read.

Wallet values and ledger amounts are integer rupees. Wallet mutation and ledger
creation are atomic Firestore transactions. Users on hold cannot write wallet
or profile data. The Admin Payment methods page stores `settings/app.addMoneyMethod`.
Only Gateway and Off can be selected: Gateway permits new TranZUPI top-ups and
Off rejects them. Manual is disabled in Admin and legacy saved `manual` values
fail closed as Off. Existing gateway orders can still be confirmed after the
method changes. If the setting is absent, Gateway remains the default to
preserve the existing top-up behavior.

## Firestore setup

The defaults in `settings/app` are `minAdd: 5`, `maxAdd: 100`,
`minWithdraw: 20`, `dailyLimit: 100`, and `maintenance: false`. If the settings
document is absent, the API uses these defaults without creating a document.
Create it once (without overwriting an existing settings document) with:

```powershell
python scripts/seed_settings.py
```

For an existing settings document, update only the minimum add-money amount:

```powershell
python scripts/seed_settings.py --min-add 5
```

Configure TranZUPI locally in `backend/.env`; never commit or share the API key:

```dotenv
TRANZUPI_API_KEY=your_tranzupi_api_key
TRANZUPI_REDIRECT_URL=https://your-public-backend.example/pay/return
TRANZUPI_BASE_URL=https://www.tranzupi.com
```

The redirect URL must use HTTPS. Configure TranZUPI to send its webhook to
`https://<your-public-backend>/api/payments/tranzupi/webhook`. The webhook body
is not trusted for settlement; the backend verifies each order with the
provider's status API. The user app opens the hosted payment page and polls the
authenticated status endpoint while the app is active.

Deploy the Firestore rules and composite indexes from `backend/`:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

Rules allow clients to read only their own user, wallet, notification, and
transaction documents; all client writes and all other collection access are
denied. The Flask server uses Firebase Admin credentials for server-side writes.

Grant an existing Firebase user the admin custom claim by email:

```powershell
python scripts/make_admin.py player@example.com
```

## Tournament admin

The admin UI and player API use the same Firestore `tournaments` collection.
Tournament defaults are saved in `tournamentDefaults`; dashboard counts and
the APK tournament lists are derived from those documents. Start the existing
admin UI with `python ADMIN/admin_app.py` from the workspace root. Set
`ADMIN_PASSWORD` and `ADMIN_SESSION_SECRET` in the environment (or
`backend/.env`) before exposing the panel; set `ADMIN_COOKIE_SECURE=true` when
serving it over HTTPS. Optional banner uploads require `STORAGE_BUCKET`;
selecting one of the bundled Flutter images does not.

The admin UI can create normal and free loot tournaments, save and reuse
defaults, show Firestore-backed dashboard counts, and save room credentials.
Room details are notified only to users who joined that tournament. Its
Notifications page can send an in-app inbox message and push alert to all users
or one player (by Firebase UID or game UID). Hold, wallet-credit, and
maintenance-start actions also create professional English notifications.
Push delivery requires the player app to be signed in, notification permission
to be enabled, and its installation ID to be registered; inbox messages remain
available in the app even if push delivery is unavailable.

The tournament player list shows only occupied slots in ascending slot order.
Deleting a tournament removes its entries and slot claims and refunds each
joined player's entry fee to the deposited wallet balance with a Firestore
ledger entry. In the APK, the home carousel shows only live tournaments while
any are live; otherwise it shows upcoming tournaments only. The separate
upcoming-tournament list also excludes completed matches, and the app refreshes
when a carousel timer ends. Players who joined a deleted tournament also
receive a cancellation message in their Firestore notification inbox and a
push notification when a registered device is available.

The Admin **Check and edit** page can search a player by account UID or game
UID, show their wallet, match statistics, and transaction ledger, and deduct
from deposited or winnings balances. Deductions are whole-rupee Firestore
transactions with an immutable wallet-ledger entry, an `auditLogs` record, and
a player notification; a deduction cannot make a balance negative.

## Tests

```powershell
python -m unittest discover -s tests -v
```
