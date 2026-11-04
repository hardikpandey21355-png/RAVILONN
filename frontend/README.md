# Ravilon

Flutter application scaffold. The separate Python admin service remains in
[`ADMIN`](../ADMIN).

## Run

```powershell
cd frontend
flutter pub get
flutter run
```

For a USB-connected Android phone, start the backend first, then use:

```powershell
.\tool\run_on_phone.ps1
```

The script forwards the phone's `127.0.0.1:5000` to the backend on this PC and
starts the debug app. USB reverse forwarding is removed when the device
disconnects, so run the script again after reconnecting it.

## Project layout

```text
lib/
  app/                 App root and app-level configuration
  core/                Shared foundational code (theme, utilities, services)
  features/
    home/
      presentation/    Home screen and UI
  main.dart            Application entry point
test/                  Flutter tests
android/ ios/ web/     Mobile and web platform projects
windows/ macos/ linux/ Desktop platform projects
```

Add each new feature under `lib/features/<feature_name>/`, grouping its
`data/`, `domain/`, and `presentation/` code there as the feature grows.
