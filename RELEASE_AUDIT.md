# Release audit — 15 October 2026

This report covers the repository changes made during this audit. Passing automated checks does not establish that an application has no bugs or security vulnerabilities. Production deployment, Firebase console settings, and physical-device behavior require separate verification.

**Release status:** the application passes the checks below, a signed Android bundle has been built, and 29 checks passed on the connected Android phone using an isolated QA package. Production release remains gated by the recovery/identity decision and production/store configuration verification described below. See `MOBILE_TEST_REPORT.md` for device evidence and limits.

## Findings and fixes

| Finding | Impact | Change |
| --- | --- | --- |
| Auth observer called `clearSession()` after an account replacement. That method also signs out Firebase Auth; a failed delayed reload could also sign out a replacement user. | A delayed cleanup or reload error could sign out the replacement account and delete its session. | Removed session mutation from the observer; explicit logout owns that operation. Clear the previous UID's provider cache. Check the current auth state again before deferred login navigation and only sign out on a reload error if the same UID is still active. |
| Profile getters returned cached names and email when no Firebase user was signed in. | Signed-out code could read another session's personal metadata. | Require a current authenticated UID and matching phone and UID before returning cached profile fields. Updated security regression tests. |
| Provider listener cancellation was asynchronous without invalidating the pending fetch. | Logout or disposal during cancellation could attach a fresh listener for the previous account, repopulate cleared records, or notify a disposed provider. | Added generation and disposal guards to expense and friend subscription setup, callbacks, and errors. Added four delayed-cancellation regression tests. |
| Expense deletion could restore its optimistic backup after a different account had loaded. | An old failed deletion could insert the previous account's transaction into the new account's UI. | Restrict rollback and split-deletion UI updates to the generation that started the operation. |
| Profile hydration, loading, and update operations could finish after state was cleared or disposed. | Stale profile data could reappear or trigger notifications after disposal. | Added generation, UID, and disposal checks; clearing the profile releases the loading state so a new account can load. |
| `clearUser()` used the currently authenticated UID when deleting a cache during account replacement. | Cleanup for the previous account could delete the new account's cached profile. | Pass the previous UID explicitly and avoid deleting the new UID's cache. |
| Editing a legacy linked split normalized `Owed to …` to `Owed` in the write. | Database rules correctly rejected an otherwise permitted description/date/category edit because the linked payment mode is immutable. | Preserve the stored payment mode for linked entries after validating the requested mode. |
| Current npm audit found seven high-severity dependency findings in development tooling. | Vulnerable FTP parsing and glob parsing dependencies were present in the Firebase CLI dependency tree. | Applied compatible lockfile updates and scoped a Firebase CLI override to CommonJS-compatible `chokidar` 4. The CLI watches explicit paths in the audited implementation. Re-ran emulator tests and npm audit. |
| The default rules test command omitted the startup-policy suite. | CI could miss regressions in unauthenticated startup configuration access. | Run every `test/firebase/*.test.mjs` suite. |
| UI fonts were downloaded dynamically by `GoogleFonts.poppins()`. | First launch depended on an additional third-party font request and could produce asynchronous errors offline. | Bundle the four Poppins weights used by the UI and their license, use a local font family, and remove the unused `google_fonts` package. This does not remove the app's Firebase startup requirements. |
| Web metadata still identified the product as `account` / a new Flutter project. | Installed web apps and browser tabs showed placeholder branding. | Set FinTrack title, description, manifest name, and brand colors. |
| Local SDK and CI used different Flutter versions; enforcing the old lockfile failed with the installed SDK. | Builds were not reproducible across the audited machine and CI. | Pin CI to the installed Flutter 3.47.7 and regenerate the lockfile for its SDK dependencies. Keep major application dependency upgrades out of this patch. |
| System Java 25 is incompatible with the project's Gradle 8.14. | Android release compilation failed before app compilation. | Retry packaging with a portable JDK 21 under ignored `build/audit-jdk`, without changing the system Java installation. Added `tool/build_release.ps1 -JdkHome <absolute-JDK-21-path>` to validate Java, enforce the lockfile, run analyzer/tests, and build a signed bundle while restoring environment settings afterward. |
| Kotlin incremental caches failed with `this and base files have different roots` for plugins in the C: Pub cache and the project on D:. | Repeated compiler-daemon failures and slow fallback compilation during Windows release builds. | Disable Kotlin incremental compilation in the project's Gradle properties. This trades incremental build speed for reliable builds across drive roots. |
| Android unconditionally added the `integration_test` project to `implementation`, overriding Flutter's release exclusion for development plugins. | Production dependency resolution included test runners, Espresso, and test-only transitive libraries. | Restrict the explicit test-plugin dependency to the isolated QA package. Let Flutter regenerate its release plugin registrant by omitting `--no-pub` on the final native build; a stale debug registrant otherwise references the correctly excluded test plugin. |
| CI's Android build depended on ignored local `google-services.json` files, and neither production nor QA JSON was tracked. | A fresh CI checkout could not run the native build gate. | Add a tracked, explicitly fake loopback-only QA configuration template; have CI prepare it and compile the isolated smoke-test target. The local device helper also prepares the template when absent. No production configuration or credentials were added. |
| The QA network security configuration omitted `127.0.0.1`, used by USB-forwarded Firebase emulators. | Physical-phone QA could not reliably reach its local backend. | Add a domain-scoped loopback allowance through resources included only in the isolated QA debug build; retain the default cleartext denial. |
| Device input helpers assumed a form was ready immediately after navigation. | Native rendering delays caused a false acceptance-test failure. | Wait for the target page and field before interaction; add a delayed-field regression test. |

## Scope and remaining release gates

- No production database writes, rules deployment, publishing, account migration, or store submissions were performed.
- The checked-in rules were tested locally; this does not verify that production has deployed those rules. Back up production data and use the documented migration/deployment procedure before release.
- Confirm production password policy, email enumeration protection, quotas, authorized domains, and App Check configuration. Console settings cannot be inferred from source. Firebase guidance: https://firebase.google.com/support/guides/security-checklist.
- The existing login model uses `phone@fintrack.app` as a password account identifier. It does not verify possession of the phone or provide a usable email password-recovery flow. The profile email is separate from Firebase Auth email. A verified recovery/identity design is still required before presenting this as verified phone authentication or offering self-service recovery; changing existing identities requires a migration plan.
- Android physical-device QA passed on one Android 13 / API 33 phone: money flows, offline retry, process restart, encrypted session/draft recovery, access denial, native exports, and account deletion. See `MOBILE_TEST_REPORT.md`. This used a debug QA package and local Firebase emulators; Play-distributed production acceptance, other OS versions, upgrade/restore, and full multi-account UI testing remain unverified.
- iOS, macOS, and Windows release packages were not certified by this audit. Linux Firebase configuration is explicitly unsupported. Do not advertise platforms beyond the platforms actually packaged and acceptance-tested.
- Native PDF preview opened and cancelled successfully on the phone. PDF export still attempts remote PDF fonts with fallback. First-use offline export and the scripts used by target users remain unverified; bundled UI fonts do not establish PDF glyph coverage.
- Store listing, privacy disclosures, support contact, account-deletion requirements, signing custody, and backup/restore procedures need owner verification before submission.
- Flutter 3.47.7 warns that support for AGP 8.11.1 and Kotlin 2.2.20 will be dropped in a future Flutter version. These are warnings in the pinned SDK; plan a separately tested Android toolchain upgrade before upgrading Flutter again.

## Verification

Local logs are in ignored `build/audit-*` files and are not release artifacts.

- Pre-device Flutter suite: **140 passed; one intentionally skipped production browser startup probe**. Includes eight new lifecycle/account-security regression tests. The final post-device rerun is recorded in `MOBILE_TEST_REPORT.md`.
- Firebase emulator suites after dependency changes: **21 passed**.
- Owner migration tests: **5 passed**.
- npm dependency audit after fixes: **zero known vulnerabilities**, including development dependencies, at audit time.
- Production JavaScript web build: **passed**, with the optional WebAssembly compatibility dry run disabled after it stalled. The emitted font manifest includes all four local Poppins weights. This is a compilation check, not browser acceptance testing.
- `flutter pub get --enforce-lockfile`: **passed** after refreshing the SDK lockfile.
- Release helper PowerShell syntax: **passed**.
- Final `flutter analyze --no-pub`: **passed with no issues**.
- Session and delayed-cancellation tests after the final guard refinements: **10 passed**.
- Gradle production `releaseRuntimeClasspath` dependency inspection: **passed**; no `integration_test` dependency remains in the release graph.
- Generated release Java plugin registry inspection: **passed**, with the test plugin excluded.
- Tracked QA template identity/loopback checks and device-helper PowerShell syntax: **passed**. CI execution on GitHub was not triggered during this audit.
- Read-only production startup probe: **HTTP 200**, returning `null` for `app_config/min_version` (no minimum version currently configured). No private production records were queried.
- Four direct authentication regression tests: **passed**, covering replacement-session preservation, deferred navigation, stale refresh failure, and current-account disable handling.
- Final Android production release build, including the last authentication changes and test-plugin exclusion: **passed** (62.6 MB bundle, 65,658,316 bytes).
- JDK 21 `jarsigner -verify`: **exit 0; `jar verified.`** The verifier also reports the self-signed certificate/no trusted CA chain, no signing timestamp, and differing manifest visibility between `JarFile` and `JarInputStream` archive readers. This is not Google Play acceptance certification; review the full local signature log and validate the bundle in the intended distribution workflow before publishing.

Artifact: `build/app/outputs/bundle/release/app-release.aab` (version `2.2.0+8`).

SHA-256: `72F5B04C1AD70CAF19C6A9B0A78BACB75586B46F8AEC2D26ABF083F38F799A95`.
