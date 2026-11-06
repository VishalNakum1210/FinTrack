# Play preparation verification — 31 October 2026

Candidate: FinTrack 2.2.3+11. Support: daku.9705@gmail.com. Creator credit: Vishal Nakum in Profile and Terms/Privacy. No postal address, website publication or Play upload.

| Check | Result |
| --- | --- |
| Locked dependencies / analyzer | Passed; no analysis issues |
| Flutter tests | 148 passed, one intentionally skipped production browser probe |
| Migration tests | 5 passed |
| Creator credit / privacy regression | Narrow-screen and 1.8x text tests passed; actual data, retained markers and support asserted. About dialog exposes support and registered bundled Poppins license |
| Public-policy submission guard | Rejects missing HTTPS URLs; drafts are deliberately marked unpublished |
| Node development tooling audit | Compatible updates removed all high findings; 13 moderate glob/minimatch-related findings remain. No forced downgrade/major override. Node tooling is not in the APK/AAB |
| CI security threshold | Workflow not triggered; its moderate-level audit gate would still fail on these 13 findings. Threshold has not been lowered to conceal them |
| Firebase rules rerun | 21 passed with updated tooling |
| Signed APK/AAB | Final builds passed; pinned signatures and package/version verified; AAB validated by Google bundletool 1.18.3 |
| 16 KB static checks | APK zipalign passed; all 8 ELF64 libraries in each artifact passed LOAD alignment; AAB requests PAGE_ALIGNMENT_16K |
| Runtime / Play acceptance | Not certified. No fresh Play-delivered split/16 KB runtime/upgrade acceptance completed |

Local logs: build/play-release-build.log, build/play-release-npm-after.json, build/play-release-npm-fix.log, build/play-release-migration.log, build/play-release-rules.log. Earlier physical phone checks are historical (MOBILE_TEST_REPORT.md), not new 2.2.3 Play testing.

Remaining public-release conditions: public hosted privacy and deletion URLs, owner retention/backup review, current synthetic store screenshots/graphics, reviewer account supplied privately, Console declarations/identity/signing choices and required testing. Existing production password-policy change remains unapplied after an earlier automatic approval rejection; no new production change was attempted in this preparation. See PRODUCTION_RELEASE_CHECK.md.

Sources and full checklist: PLAY_STORE_RELEASE.md. The terms/privacy changes reflect implementation and current Play guidance; they are not a guarantee of legal enforceability or Google acceptance.


## Final artifacts

APK: build/direct-release/2.2.3+11/FinTrack-2.2.3+11-universal.apk (66,337,381 bytes).
SHA-256: `98f7e1ef903cedda63b013d71dc809df69f417e7188d502eab090761b26e577b`.

AAB: build/play-release/2.2.3+11/FinTrack-2.2.3+11.aab (65,199,033 bytes).
SHA-256: `6d1f2a07aed4221d62ddeede2491d3aec14a99ddcf09a2e45ed6f555de5022a5`.

Package com.vishalnakum.fintrack; versionName 2.2.3, versionCode 11; minimum API 24, target API 36. ARM32, ARM64 and x86-64 native libraries. Existing signing-certificate SHA-256 retained: `f37310e2864bc1ea0d48f837c028b0a7f53f326fc50d76427c6096bd4c18b80b`.

Final checks used build/play-release-final-build.log, build/play-bundle-final-validation.log, build/play-bundle-final-config.json and build/play-bundle-final-manifest.xml. Poppins OFL entry is present inside both final archives; its contents are available through About > Licenses. APK providers are non-exported; launcher and expected Firebase Auth activities remain exported. Manifest has no Contacts/SMS/location/storage runtime permission request. App transport defaults to cleartext denied and backup disabled. These checks do not certify every SDK against all vulnerabilities.

No production app was installed/replaced, no real financial records were read, and no backend policies or rules were changed by this preparation. No website or Play upload was performed. The earlier 2.2.2 artifact and reports are historical; use these candidates for the new creator credit and policies.
