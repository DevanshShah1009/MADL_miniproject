# MotoLog verification report

Verification date: 21 October 2026 (Asia/Calcutta).

## Automated checks

| Check | Result |
| --- | --- |
| Flutter doctor -v | Android toolchain and licences passed. Flutter/Dart not on PATH; explicit SDK paths used. Windows desktop Visual Studio absent, not required for Android. |
| flutter pub get | Packages resolved and downloaded; command exited 1 because Windows Developer Mode/symlink support is disabled. Android checks/builds use the resolved lockfile with --no-pub. |
| dart format lib test tool | Passed. |
| flutter analyze --no-pub | No issues found. |
| flutter test --no-pub | 17 tests passed. |
| flutter test tool/preview_test.dart --no-pub | 1 additional rendering test passed for all five tabs at 412 × 915; screenshots visually inspected. |
| flutter build apk --debug --no-pub | Passed after disabling cross-drive Kotlin incremental caches. |
| flutter build apk --release --no-pub | Universal APK produced; see build-release.log for the final build output. |

Tests cover fuel amount rounding and invalid values; full-tank/partial-fill intervals; duplicate/decreasing readings; odometer warnings; calendar-day and mileage deadlines; service intervals; spending/categories/date filters/cost per km; malformed/duplicate/orphan backup input; CSV escaping and formula neutralization; real SQLite CRUD, transactional restore, foreign-key rejection/cascade deletion and service-history retention; persistence after closing/reopening a file-backed database; clear-all; all five navigation destinations; required vehicle fields and creation; fuel auto-total/zero rejection; and 360-pixel screen layout.

Initial test failures were fixed, including an incorrect expected rounding amount and widget test scrolling/asynchronous database setup. The final suite passes without suppressing analysis rules or removing the failing scenarios. Initial debug compilation failed in Kotlin's incremental cache because the plugin source path was on C: while the project was on D:. The project-local Gradle workaround is documented in README.md.

## Output

- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/flutter-apk/app-release.apk`
- `docs/previews/`: synthetic test fixtures, not actual user data.
- `test-results.log`, `preview-results.log`, `build-debug.log`, `build-release.log`: actual tool outputs.

## Manual Android checks still required

The APK was built, not silently installed on the connected personal phone. Automated SQLite reopen tests do not substitute for the following hardware checks:

1. Install the release APK; create two vehicles. Add, edit and delete fuel/service/reminder entries. Verify vehicle filtering and immediate dashboard updates.
2. Force-stop and reopen the app. Confirm the garage, odometer, records and preferences persist.
3. Export both CSV files and JSON using Android's system picker. Restore JSON after confirming replacement. Try a malformed file and confirm current data remains.
4. Deny notification permission and confirm reminders remain in-app. Then enable permission and test an upcoming reminder, a completed reminder and mileage-triggered status.
5. Reboot; verify retained pending schedules. Change timezone and reopen MotoLog to reconcile local times. Android power restrictions can delay notification delivery.
6. Confirm delete-vehicle and clear-all cancellation preserve data, while confirmation removes the specified data.
7. Exercise forms with the soft keyboard, large accessibility text and the phone's system insets; inspect light and dark themes.

## Delivery scope

Metric units only; no photo/receipt attachments, merge import, remote backend, or automatic mechanical recommendations. Currency switching relabels rather than converts values. Local notifications are capped at 60 pending schedules and depend on OS permission/power rules. Release uses the standard local debug signing key for an installable college-project build; configure a private release key before public distribution. No signing secrets are committed.

## Final APK inspection

The final release build completed in 68.3 seconds. Android `aapt dump badging` verified package `com.motolog.app`, display name `MotoLog`, version `1.0.0` (code 1), minimum Android API 24 (Android 7.0), target API 36, and universal native libraries for arm64-v8a, armeabi-v7a and x86_64. `apksigner verify --verbose` passed with APK Signature Scheme v2 and one signer.

Release file size: 54,873,308 bytes (Flutter reports 52.3 MB).

SHA-256: `26BD94714ED730D18B9A6DADF9C3B95B91A795B04E5F66702F2DF264B08FA8DD`.
