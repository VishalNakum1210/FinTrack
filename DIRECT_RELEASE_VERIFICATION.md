# Direct APK release verification — 22 October 2026

Target release: **2.2.2+10**, package `com.vishalnakum.fintrack`, outside the Play Store.

## Current results

| Check | Result / evidence |
| --- | --- |
| Locked Flutter dependencies | Passed: `flutter pub get --enforce-lockfile` |
| Static analysis | Passed: no issues |
| Full Flutter suite | **144 passed, 1 intentional skip** (production browser probe) |
| Offline PDF regression | All four exporters generated PDFs with embedded fonts and **zero network-client creations** |
| Firebase rules emulator suite | **21 passed** after the dependency patch |
| Owner migration tooling | **5 passed** |
| npm security audit | **0 known vulnerabilities** after updating the transitive MCP SDK |
| Deployed production database rules | **Exact structural match** with `database.rules.json`, checked read-only |
| Public production startup policy | **HTTP 200**, `null` minimum version (no minimum-version restriction configured) |
| Firebase Auth configuration | Password sign-in and email-enumeration protection **enabled**; no custom password policy configured. Initial global-account request returned 403; the project's selected account succeeded |
| Installed phone app signing compatibility | Installed **2.2.1+9** APK verifies and has the pinned release certificate; production app/data untouched |
| Reject unsafe distribution artifacts | Verifier rejects both the outdated installed 2.2.1+9 APK and the debug QA APK |
| PowerShell helpers | Parsed successfully; completed the full build, APK verification and distribution copy |
| Signed APK | **Passed**: production package/version, pinned certificate and v2 signature, manifest flags, cleartext denial, and QA-resource exclusion |
| Release plugin registry | `integration_test` excluded |

Artifact: `build/direct-release/2.2.2+10/FinTrack-2.2.2+10-universal.apk`, **65,925,333 bytes** (62.9 MiB), Android **7.0 / API 24+**, targeting API 36, with ARM32, ARM64 and x86-64 native libraries.

APK SHA-256: `dbce7754f9745770587b9e59645a218e78ea7513d97071bf6ab687eb39310363`.

Signing-certificate SHA-256: `f37310e2864bc1ea0d48f837c028b0a7f53f326fc50d76427c6096bd4c18b80b` (matches the installed phone app). Checksum and metadata are also in the distribution folder's `SHA256SUMS.txt` and `verification.json`.

Local evidence: `build/direct-release-build.log`, `build/direct-release-pdf-test.log`, `build/direct-release-rules.log`, `build/direct-release-migration.log`, `build/direct-release-npm-fix.log`, `build/direct-release-backend-check.json`, and `build/direct-release-installed-apk-check.log`. These ignored files are local audit evidence, not distribution files.

The earlier **29-check physical-phone acceptance run** remains documented in `MOBILE_TEST_REPORT.md`. It exercised an isolated debug QA package/local Firebase backend on 15 October, before the changes above. It is not a fresh installation/upgrade acceptance result for the new production APK. This run read the installed app binary solely to compare its public signature; it did not replace or launch the production app or read user records.

## Issues fixed for direct distribution

| Problem | Fix |
| --- | --- |
| Existing release helper produced an AAB; old split APKs were easy to distribute accidentally | Default to a signed universal APK, check its exact package/version, copy only the verified file into a versioned distribution folder, and include SHA-256 and installation notes |
| APK signature/update compatibility was not checked by the packaging helper | Use Android `apksigner`, require APK signature scheme v2 and the pinned existing release certificate; compare it with the installed phone app |
| Production network XML retained local cleartext exceptions | Remove them from production; QA uses its own loopback-only resource |
| PDF generation fetched fonts and fell back silently on failure | Load bundled regular/bold Poppins for all four PDF document types, without network access; use document-local font instances |
| Recovery action gave only a vague toast and registration omitted recovery limits | Provide a scrollable help dialog and explicit registration/Terms disclosures, preserving existing account IDs |
| App presented an unverified support mailbox and stale privacy footer version | Remove the mailbox; default to the APK distributor and signed-in Feedback; allow a verified email via build define; refresh footer |
| New MCP SDK advisories affected development tooling | Update the compatible transitive dependency; rerun audit, emulator rules and migration tests |
| Existing version could collide with a shipped installation | Increment to **2.2.2+10** while retaining package and signing key |
| README implied a full backup/restore capability | Describe the actual current-user JSON export and lack of in-app restore |

## Distribution decision and owner checks

The owner explicitly chose to preserve the existing phone/password account model and disclose recovery limits. A phone number is an unverified account ID; profile email does not enable email reset. Administrator-assisted recovery needs independent ownership evidence. Do not use knowledge of profile fields alone to reset accounts. This limitation is now visible before registration and through login help. The owner did not supply a working support mailbox; email support stays unconfigured, with directions to the APK provider or signed-in Feedback rather than a fake inbox.

The remaining concrete configuration change is enforcing the APK's 12–128 character password policy on the server without forced sign-in upgrades. See `PRODUCTION_RELEASE_CHECK.md` and `tool/release_password_policy.json`. Automatic approval review rejected this production write because the exact configuration change lacked explicit approval; **it was not executed**. Password sign-in and enumeration protection were verified as enabled using the project's selected Firebase account.

Usage quotas/alerts, a monitored support channel and backup/signing-key custody remain owner operational checks. App Check is not integrated in this client; do not enable enforcement until a compatible provider has been added and tested for direct distribution. No production database writes, configuration changes, account migrations, publishing or Play Store submission were performed.

The APK targets the tested source and is prepared for direct installation. Public distribution remains pending the production policy decision above and normal install/update acceptance on intended devices. No audit can certify an absence of all bugs or vulnerabilities.
