# FinTrack — Play preparation, 31 October 2026

Release candidate: 2.2.3+11. Created by Vishal Nakum. Support: daku.9705@gmail.com. No postal address is embedded in the app or draft pages. No Play upload or website publication is authorized/performed by this preparation.

## Completed in source

- Visible creator credit in Profile and Terms/Privacy, separate from customer identity; existing cryptographic signing key retained.
- About dialog shows authorship/support and opens Licenses. Poppins OFL is included in app assets and registered with Flutter's license registry, rather than existing only in the repository.
- Corrected privacy disclosures: profile address, feedback, Firebase processing, operator access, local caches, exports and retained ownership/deletion markers.
- Replaced absolute zero-liability language with service limitations that preserve non-excludable legal rights. This is an implementation/policy review, not a legal enforceability opinion for every jurisdiction.
- Real support email configured. Phone/password accounts retained with explicit recovery limits; no identity migration.
- Signed APK/AAB candidate build and verification workflow; final submission mode refuses missing/non-public draft policy URLs. A successful gate is a basic availability check, not Google approval or certification of page content.
- Store copy, Data Safety worksheet, reviewer/testing instructions and public-policy page drafts prepared under release/play-store.

## Remaining submission gates

1. Host privacy.html, terms.html and delete-account.html on a publicly accessible HTTPS host. A purchased domain is unnecessary: GitHub Pages or another suitable free host can supply an address. Review the content, remove the DRAFT banner only when actually ready, and provide the resulting privacy/deletion URLs. Local files do not satisfy a public URL requirement.
2. Monitor the supplied mailbox and establish independent ownership verification for deletion/recovery requests. Retained marker has no automatic expiry: document its security purpose, assess necessity and set an owner-reviewed retention schedule. Confirm Firebase backup/log retention; no invented purge timeframe is promised here.
3. Production password-policy proposal remains unapplied following the earlier automatic approval rejection. Approve the exact change in PRODUCTION_RELEASE_CHECK.md separately if desired. Do not bypass it as part of store preparation.
4. Complete developer identity/contact verification and Play Console app-content forms. Not publishing a postal address in this app does not waive information Google may require from developer accounts.
5. Review Data Safety against the final SDKs and actual backend operations. Declare financial features honestly: this is expense/budget management, not lending, payments, bank connectivity or investment execution. Do not automatically select 'no financial features' merely because the app does not transfer money.
6. Create a dedicated reviewer account using the supported registration flow, with synthetic records only; give credentials privately in App access. Do not commit credentials or expose real users' data. Do not create production accounts automatically as part of packaging.
7. Capture current screenshots with synthetic data, a 512x512 store icon and 1024x500 feature graphic. Existing screenshots are references, not automatically approved current store assets. Complete content rating/target audience accurately; do not claim Families compliance without review.
8. Complete applicable Play closed testing (new qualifying personal accounts: 12 continuously opted-in testers for 14 days), pre-launch reports, 16 KB device runtime testing and an install/upgrade test. Source/ELF checks do not replace Google-generated split APK testing.
9. Decide Play App Signing custody before first upload: to preserve updates between direct APK and Play, consider securely enrolling the existing app signing key rather than accepting an unrelated new key. Google signing-key changes are not performed here.

## Build

`./tool/build_release.ps1 -JdkHome '<JDK21>' -AndroidSdk '<SDK>' -Format Both`

Candidate APK: build/direct-release/2.2.3+11/. Candidate AAB: build/play-release/2.2.3+11/. These replace no installed app and upload nothing.

Once public pages exist, final preparation may use `-PlaySubmission -PrivacyUrl 'https://...' -DeletionUrl 'https://...' -Format Both`. This does not upload the app. APK/AAB hashes and verification results are recorded in PLAY_STORE_VERIFICATION.md after the run.

## Primary requirements checked

- User Data / privacy: https://support.google.com/googleplay/android-developer/answer/10144311
- Account deletion: https://support.google.com/googleplay/android-developer/answer/13327111
- App content / reviewer access: https://support.google.com/googleplay/android-developer/answer/9859455
- Financial features: https://support.google.com/googleplay/android-developer/answer/13849271
- Target API: https://support.google.com/googleplay/android-developer/answer/11926878 (phone/tablet requirement currently API 36)
- Testing: https://support.google.com/googleplay/android-developer/answer/14151465
- 16 KB support: https://developer.android.com/guide/practices/page-sizes
- Firebase processing: https://firebase.google.com/support/privacy

No audit establishes absence of all bugs or vulnerabilities. Preparation does not establish acceptance by Google.
