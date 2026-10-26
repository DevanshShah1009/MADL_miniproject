# MotoLog

Offline Android vehicle maintenance companion built with Flutter, Material 3, Provider and SQLite. Application ID: `com.motolog.app`; version: `1.0.0+1`.

## Features

- Five persistent navigation tabs: Dashboard, Vehicles, Records, Analytics and Settings.
- Multiple vehicles, type-based avatars, purchase date, registration, fuel type, notes and editable odometers.
- Fuel, maintenance and reminder CRUD with confirmations, search, vehicle/date filtering and history details.
- Full-tank efficiency that includes intervening partial fills and rejects non-increasing or duplicate-date intervals. No invented statistics or starter records.
- Dashboard spending, latest efficiency/service, deadlines, quick actions and recent activity.
- Interactive six-month expense charts, fuel/service trend filters, category breakdowns, efficiency history and conservative interval cost/km.
- Date and odometer service schedules, insurance/PUC/licence/custom documents, completed/dismissed states and optional Android notifications.
- JSON backup with complete validation before transactional replacement. Fuel/service CSV export with currency headers, CSV escaping and formula-injection protection.
- Dark/light/system themes, currency labels, default lead time, notification preference, confirmed data clearing and open-source licences.

## Structure

- `lib/app/`: app shell, navigation, design tokens and themes.
- `lib/core/models.dart`: typed null-safe vehicle and history models.
- `lib/core/repository.dart`: SQLite schema v1, foreign keys, indexes, transactions, CRUD, backup/restore and CSV.
- `lib/core/calculations.dart`: validation, efficiency, expense aggregation and deadline logic.
- `lib/core/store.dart`: Provider/ChangeNotifier state; refresh after writes and app resume.
- `lib/core/notifications.dart`: permission handling and reconciliation of Android schedules.
- `lib/features/`: dashboard, vehicles, records, analytics and settings.
- `test/`: business rules, real SQLite CRUD/restore/reopen and widget tests.
- `tool/preview_test.dart`: isolated synthetic fixtures for screen rendering; never loaded by the application.
- `docs/previews/`: test-rendered mobile screenshots, using sample data only.

## Build

This workstation has Flutter at `C:\src\flutter\bin`, Android SDK at `C:\Users\Devansh\AppData\Local\Android\sdk`, and Android Studio's bundled JDK. Flutter doctor verified Flutter 3.47.7, Dart 3.13.5, Java 25.0.3 and accepted Android licences. Gradle 9.3.1 is provided by the project's wrapper. Git is installed; this directory is not a Git repository.

Add Flutter's `bin` directory to PATH, then run from this project:

```powershell
flutter pub get
dart format lib test tool
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

On this Windows machine, dependency resolution downloads successfully but `flutter pub get` reports that Windows plugin symlinks require Developer Mode. Enable Windows Settings → System → Advanced → For developers → Developer Mode (the exact settings location can vary), or open `ms-settings:developers`. No Windows desktop toolchain is required to build Android. Once dependencies are resolved, the verified Android commands can use `--no-pub`:

```powershell
C:\src\flutter\bin\flutter.bat test --no-pub
C:\src\flutter\bin\flutter.bat analyze --no-pub
C:\src\flutter\bin\flutter.bat build apk --debug --no-pub
C:\src\flutter\bin\flutter.bat build apk --release --no-pub
```

`android/gradle.properties` disables Kotlin incremental compilation because this machine has package-cache sources on C: and the project on D:. This fixes the observed Kotlin relative-path cache failure. The pinned file_picker currently emits a future Kotlin Gradle migration warning; it builds on the verified toolchain. Java emits a native-access warning, which is not a build failure.

## Install on Android

The universal release output is `build\app\outputs\flutter-apk\app-release.apk`. Copy it to the phone via USB, Drive or another file-transfer method. Open it using the phone's Files app, allow installation from that app if Android asks, and choose Install. Enable notifications in MotoLog Settings only if wanted.

The release build currently uses the standard local Android debug signing key for this college-project delivery. It is directly installable, but it is not configured for Play Store publication. No key, password or signing secret is stored in the repository. Use a private release keystore before public distribution, and keep the same signing key for future updates. Do not uninstall an existing installation to solve a signing mismatch without exporting a backup first.

Rebuild using the same release command after code changes and transfer the newly generated APK. Increment `version: 1.0.0+1` in pubspec.yaml for distributed updates.

## Data and calculation rules

- Five SQLite tables: vehicles, fuel, maintenance, reminders and settings. History/reminder foreign keys cascade on vehicle deletion. Writes that affect odometers and records, full restore and clearing use transactions.
- Database schema version is 1. No legacy MotoLog schema existed in the starter. Unknown future upgrades fail safely; future versions need explicit additive migrations, never delete-and-recreate fallbacks.
- Date/time values are epoch milliseconds; JSON creation timestamps use UTC. Expiry comparisons use the device's local calendar day.
- A fuel fill raises the vehicle odometer only if its reading is higher. Historical edits/deletions do not roll the vehicle odometer backwards. Editing the vehicle itself can lower it after a warning.
- Full-tank calculations exclude the first fill's litres and include all fills through the closing full tank. They assume comparable tank fill levels. The app intentionally does not invent estimates when a reliable interval is absent.
- Cost/km is a sample spanning the first and last full fills in the active date filter. It excludes the opening fill and requires strictly increasing readings. It is not a lifetime depreciation/ownership calculation.
- Currency changes relabel amounts, never convert them. All distance/fuel data uses km and litres.
- Restore is replace-only, with a count preview and confirmation. Schema, types, IDs, relationships, dates, numeric ranges and settings are validated before writing. Imports above 20 MB are rejected.
- The app has no remote backend or account. Android automatic cloud backup is disabled; use the explicit JSON export. Exported files include user-entered identifiers and notes, so keep them private.

## Notification behavior and scope

Notifications are optional and use inexact Android alarms; exact delivery is not guaranteed. Stable IDs and cancel/reconcile prevent duplicate pending schedules. Boot receivers restore pending schedules. Opening/resuming the app reconciles changes, including timezone changes. Up to 60 active schedules are queued; additional reminders remain visible in-app. Odometer-only alerts are scheduled once an entered reading reaches the threshold, not from background vehicle telemetry. Missed/past lead dates are moved to the next morning. Service schedules are user-entered reminders, not safety diagnoses.

This release uses icon avatars rather than photos; receipt/document attachments are not implemented. Units are metric only. Global documents can be tracked against a chosen vehicle. There is no backup merge mode or cloud sync. Notifications, Android file-picker interactions, actual reboot delivery and force-stop behavior still need a manual phone smoke test; automated tests validate storage close/reopen rather than claiming a physical-device force-stop test.

## Visual QA

The preview test renders all five populated tabs at 412 × 915 logical pixels, with fixture data isolated to the test. To load readable fonts in its screenshots on this workstation:

```powershell
$env:MOTOLOG_FONT_ROOT='C:\src\flutter\bin\cache\artifacts\material_fonts'
flutter test tool/preview_test.dart --no-pub
```

See `docs/QA.md` for the final verification report and manual smoke-test checklist.
