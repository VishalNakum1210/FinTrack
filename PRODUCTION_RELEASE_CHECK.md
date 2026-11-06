# Production configuration review — 22 October 2026

The signed direct-install APK is complete. One production password-policy change needs explicit owner approval before it can be applied.

Read-only checks using the project's selected Firebase account confirmed:

- Production database rules exactly match the tested repository rules.
- Password sign-in and email-enumeration protection are enabled.
- No custom `passwordPolicyConfig` is configured. The APK validates 12–128 characters, but a client-side check does not enforce policy on direct Firebase API calls.
- No custom sign-up quota was returned. Check usage/alerts for the intended distribution size; do not treat an absent custom quota as unlimited capacity.
- The public minimum-version endpoint responds HTTP 200 with `null`, meaning no minimum-version restriction is configured.

## Exact proposed change

Project: `account-flutter-58a59`

Request: `PATCH https://identitytoolkit.googleapis.com/admin/v2/projects/account-flutter-58a59/config?updateMask=passwordPolicyConfig`

Body: [`tool/release_password_policy.json`](tool/release_password_policy.json)

This enforces 12–128 characters for newly created or changed passwords. `forceUpgradeOnSignin: false` preserves existing users' sign-in without forcing a password reset. It does not migrate identities, change account passwords, delete records, change rules, or enable App Check. Older clients that submit shorter new passwords could receive a rejection; that is why a production change needs explicit approval.

After approval, apply only this masked field and read the configuration back to confirm the exact values. Retain the previous policy (currently absent) in local audit evidence. Existing account recovery limitations remain as accepted by the owner.

Automatic approval review rejected the attempted write because release preparation/recovery disclosure did not explicitly authorize this production Auth-policy change. The tool did not execute it. No production configuration or user data was changed.

Reference: [Google's password-policy configuration and sign-in upgrade controls](https://docs.cloud.google.com/identity-platform/docs/password-policy).
