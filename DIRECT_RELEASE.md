# FinTrack 2.2.2+10 — direct Android distribution

This release is prepared as a signed universal APK for installation outside the Play Store. Do not distribute an AAB, a debug APK, the QA package, or an older architecture APK left in the build directory.

## Install and update

1. Obtain `FinTrack-2.2.2+10-universal.apk` and `SHA256SUMS.txt` from the person distributing this release through a trusted channel. Verify its SHA-256 against the supplied file (Windows: `Get-FileHash -Algorithm SHA256 <apk>`).
2. Open the APK on Android and allow installation from that source when Android asks. Keep Android's security checks enabled. Disable the source's install permission afterward if it is no longer needed.
3. For an update, install over the existing FinTrack app. **Do not uninstall or clear data.** If Android rejects the signature or version, stop and contact the distributor. Never uninstall to force an update; unsynced data may be lost.
4. Keep the same signing key for future updates and increase the build number. Back up the private signing key and credentials securely, outside this distribution folder. Never share them with APK recipients.

The package is `com.vishalnakum.fintrack`; the QA package ends in `.qa`. The public signing-certificate SHA-256 is `f37310e2864bc1ea0d48f837c028b0a7f53f326fc50d76427c6096bd4c18b80b`. Supported Android ABIs and minimum SDK are reported by the built APK; this universal package includes Flutter's supported release architectures.

## User-visible limits

- A phone number is an account ID, not a verified phone identity. This release preserves existing phone/password accounts. There is no SMS login or email password-reset service; profile email is contact information. Keep the password safe. Administrator-assisted recovery requires independent ownership verification and cannot be promised. Contact the person who supplied this APK; signed-in users can use Profile > Feedback.
- Internet is required for account operations, initial startup/version checks, and server confirmation. Cached records and queued writes do not replace backups. Wait for synchronization before changing devices, logging out, or deleting data.
- Export private JSON/CSV/PDF records before destructive operations. These exports are unencrypted files; share them only with intended recipients. JSON is an archive/export, not an in-app restore feature.
- PDF fonts are bundled for offline document generation and cover Latin and Devanagari. Other scripts and complex text shaping are not certified. The device still needs a system print/share handler.
- This is a personal recordkeeping tool, not a banking connection or verified bank balance. Check important amounts against original records.

## Changes in this release

- Replace remote PDF-font downloads with bundled fonts in all four PDF exporters. A regression test generates all four document types with networking disabled and verifies embedded font data.
- Remove all cleartext network exceptions from the production Android network configuration. Local emulator exceptions remain confined to QA resources.
- Replace the vague recovery toast with an accessible explanation; disclose account/recovery limits at registration and in Terms. Remove the unverified support mailbox. A verified support email may be supplied with `--dart-define=FINTRACK_SUPPORT_EMAIL=...` when building manually.
- Patch the Firebase CLI's transitive MCP SDK security dependency. These Node dependencies are development tooling and are not packaged into the Android app.
- Build a direct-install APK, verify the production package/version, signature and pinned certificate, check production manifest/network flags and QA-resource exclusion, and export an APK checksum plus verification metadata.
- Increment version from 2.2.1+9 to 2.2.2+10 so installations can update safely.

## Build reproducibly

Use the repository's pinned Flutter version, JDK 21, configured production Firebase JSON, and the existing release keystore referenced by ignored `android/key.properties`. Do not generate a replacement key to work around missing credentials.

```powershell
./tool/build_release.ps1 -JdkHome 'D:/path/to/jdk-21' -AndroidSdk 'C:/Users/you/AppData/Local/Android/sdk'
```

The default format is `Apk`; `-Format AppBundle` or `-Format Both` is also available. The helper runs lockfile verification, analyzer and Flutter tests before packaging. Output is `build/direct-release/2.2.2+10/` with the APK, SHA-256, signature/package verification JSON, and these installation notes. Old files in `build/app/outputs/flutter-apk/` are not distribution candidates.

## Verification and backend release check

The distribution folder's `verification.json` records this APK's signature, package, version and checksum checks. In the source repository, see `DIRECT_RELEASE_VERIFICATION.md` for test results; earlier audit fixes and physical-device test scope are in `RELEASE_AUDIT.md` and `MOBILE_TEST_REPORT.md`.

On 22 October 2026, read-only checks confirmed the deployed production Realtime Database rules match the locally tested file exactly, and password sign-in and email-enumeration protection are enabled. The project has no custom password policy; enforcing the APK's 12–128 character policy on the server is awaiting explicit owner approval (see `PRODUCTION_RELEASE_CHECK.md` in the source repository). No production user records were read and no production changes were made. No Play Store submission is involved.

Owner check before public distribution: approve or resolve the server password policy, review usage quotas/alerts, provide a monitored support channel, retain production backups and signing-key backups, and test a normal install/update on the intended recipient devices. App Check is not integrated in this client; enabling enforcement requires adding and testing a provider suitable for direct APK distribution first. This audit does not promise an absence of all bugs or vulnerabilities.

Official references: [Android app signing](https://developer.android.com/studio/publish/app-signing), [Firebase security checklist](https://firebase.google.com/support/guides/security-checklist), [Firebase password authentication](https://firebase.google.com/docs/auth/flutter/password-auth).
