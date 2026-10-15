# Physical Android QA — 15 October 2026

Device: model 2201117TI (spes_in), Android 13 / API 33, arm64, 1080 × 2400. Tests used `com.vishalnakum.fintrack.qa`, the local `demo-fintrack-audit` Firebase Auth/Realtime Database emulators, and synthetic records. The installed production package was protected with before/after APK identity checks. No production data was changed or app data cleared.

## Passed: 29 recorded checks

- **22 main acceptance checks:** startup and invalid login/registration; 80-character passwords and UID ownership; zero-amount rejection; exact transaction creation/edit; self-friend rejection and friend creation; odd-paise split and retry deduplication; linked-entry edit protection and deletion; group-trip posting; forms at 1.8× text scale; offline timeout/reconnect without duplicate writes; four navigation tabs; JSON serialization and CSV formula neutralization; feedback acknowledgment; password change, logout/login; preparing an encrypted draft.
- **3 actual process-restart checks:** Firebase Auth and encrypted session survive force-stop/relaunch; the encrypted draft restores, commits once, and clears; the native Firebase SDK denies another account's ledger read.
- **4 native export/cleanup checks:** CSV and JSON share choosers open and cancel; PDF statement print preview opens and cancels; synthetic account deletion reauthenticates, returns to login, and clears local identity/draft. The user cancelled native dialogs with Back; nothing was sent or printed.

Evidence files retained locally under ignored `build/`:

| Phase | Evidence |
| --- | --- |
| Main acceptance | `build/device-qa/result-device_acceptance_test-d09ea601-20261015-163555.json` |
| Process restart | `build/device-qa/result-device_acceptance_test-d09ea601-20261015-163810.json` |
| Native exports and deletion | `build/device-qa/result-device_export_cleanup_test-d09ea601-20261015-164519.json` |
| Logs | `build/audit-mobile-acceptance-retry.log`, `build/audit-mobile-recovery.log`, `build/audit-mobile-export-cleanup.log` |

The first main test attempt failed because the harness interacted before a field appeared. After fixing synchronization, all 22 checks passed. The restart test passed its three assertions but initially timed out waiting for an unattended native chooser. MIUI denies remote Back input, so exports/deletion were resumed in a focused fixture-validating target with the user manually cancelling dialogs. The original combined restart/export invocation therefore remains a failed invocation; the separate evidence records the completed checks without concealing that interruption.

## Changes from phone testing

1. Add `127.0.0.1` to a QA-only network security resource so USB-forwarded emulators work. The resource keeps cleartext denied by default and is included only for the isolated QA debug build.
2. Wait for pages and fields in integration helpers before tapping/typing; add a regression test for a delayed field.
3. Add PDF preview coverage and a focused export/deletion resume target; extend native dialog timeouts to allow manual cancellation. These are test infrastructure fixes; the exercised application flows did not reveal an additional reproducible product bug.

Final static analysis passed with no issues. The final Flutter suite passed **141 tests**, with one intentionally skipped production browser probe (`build/audit-mobile-final-analyze.log`, `build/audit-mobile-final-tests.log`).

After deletion, direct local-emulator checks confirmed that this synthetic account's Expenses, Friends, Trips, WriteOperations, and userUpdates roots were absent. Temporary emulators and the QA app were stopped, and the test helper removed its USB forwarding rules. The QA app remains installed for review. The production release bundle hash still matches `RELEASE_AUDIT.md`.

## Release limits

This is one physical Android device with a debug QA build and local backend. It does not certify Play-installed production behavior, release performance, other phones/platforms, upgrade/backup restoration, first-use offline PDF generation, all writing scripts, or deployed Firebase configuration. A secure-storage legacy migration warning appeared after QA updates; authenticated session and draft recovery passed despite that warning. Existing-user migration from older production builds still needs separate validation.

The identity/recovery design and production/store checks in `RELEASE_AUDIT.md` remain release gates. The audit cannot establish an absence of all vulnerabilities or bugs.
