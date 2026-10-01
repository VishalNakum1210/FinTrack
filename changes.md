# FinTrack — Complete Audit and Remediation Change Log

Audit/remediation period: 30 September–1 October 2026 (Asia/Calcutta).

This document consolidates the work from the first audit, the initial fixes,
the re-audit, and the bug-only production-hardening pass. It records problems
and solutions, not changes made before this audit engagement. It replaces the
separate audit, readiness, and deployment documents removed during documentation
cleanup. The former LinkedIn post was removed rather than retained as technical
documentation. Both project README files are preserved; generated dependency
and build-folder documentation is outside this cleanup.

## Executive summary

Implemented targeted remediation of the re-audit findings without new pages or
an expanded accounting product. Existing screens and workflows were retained;
internal retry/split helpers, validation metadata, regression tests, and deployment
documentation were added. Existing unrelated working-tree changes were preserved.

The local correctness and security gates pass. Production deployment remains
conditional on the administrator migration/configuration and device/platform
checks below. Passing local tests is not a certification of the live Firebase
project, an assurance of vulnerability-free software, or proof of real-device
failure recovery. No production data or Auth settings were changed.

## 1. Initial audit and first remediation — 30 September 2026

The first audit identified three Critical, six Major, and five Minor findings.
IDs in this section belong to the initial audit; IDs in section 2 belong to the
separate re-audit and must not be confused with them.

| Original ID / problem | What changed and how the problem was solved | Main affected files |
| --- | --- | --- |
| C-01: Android release silently used debug signing when release credentials were missing | Removed the debug fallback. Release tasks require the keystore and complete signing properties, reject the standard debug alias, and fail when release configuration is missing. Debug builds remain supported. Later verified the rebuilt release AAB's public signature and non-debug certificate. | `android/app/build.gradle.kts` |
| C-02: whole-rupee rounding lost decimal amounts and split remainders | Introduced integer-paisa parsing and arithmetic, canonical two-decimal storage strings, and exact split remainder distribution. Updated provider totals, running balances, currency parsing/formatting, reports, passbook, export summaries, and edit previews. Owed expenses contribute to personal consumption totals. | `lib/utils/money.dart`, `balance_helper.dart`, `currency_helper.dart`, `split_helper.dart`; expense/friend providers; dashboard, passbook, reports and export code |
| C-03: rules accepted malformed financial fields and writable friend aggregates | Added UID-bound ownership, strict field whitelists, amount range/scale, payment/category/type allowlists, phone-key validation, calendar/timestamp checks, and default-deny authorization. Friend balances derive from records; client-maintained legacy totals are not authoritative. Added isolated emulator tests. | `database.rules.json`, `lib/utils/input_validator.dart`, `ledger_totals.dart`, `test/firebase/database_rules.test.mjs` |
| M-01: separate record and aggregate writes could disagree after partial failure | Removed independent friend-total mutations. Financial split branches use one root multi-path update; deleting a record no longer requires a separate aggregate decrement. Added stable retry journaling and duplicate-submit guards, then further strengthened retry receipts in section 2. | `lib/providers/friend_provider.dart`, `expense_provider.dart`, `lib/services/retry_safe_writer.dart`, friend/split forms |
| M-02: custom shares could be negative, incomplete, or not equal the bill | Validate finite non-negative paise amounts, unique/complete participant coverage, and exact total conservation. Recompute settlement results rather than trusting caller-provided balances. Preserve one-paisa debts and equal-split remainders. | `lib/utils/split_helper.dart`, `lib/providers/friend_provider.dart` |
| M-03: plaintext session fallback and a bundled HMAC secret were treated as protection | Removed the compiled session-signing secret and plaintext SharedPreferences identity fallback. Firebase Auth determines identity; secure local metadata is only a cache. Added ownership checks, scoped drafts/caches, and auth-change clearing/navigation. Removed unused custom password hashing and its obsolete tests; Firebase verifies passwords. | `lib/get_information/session_manager.dart`, removed `hash_password.dart`, `lib/authentication/auth_state_observer.dart`, `lib/nav_bar.dart`, user/provider/session code |
| M-04: local cooldowns did not stop server abuse; auth messages exposed account differences | Added generic credential/registration errors and duplicate-submit guards. Documented local cooldowns as UX controls, not server enforcement. Server enumeration protection, quotas, password policy, and abuse monitoring remain administrator rollout tasks. | `lib/authentication/login_page.dart`, `registration_page.dart`, `lib/get_information/password_policy.dart` |
| M-05: Firebase initialization failure still entered unusable application flows | Gate normal application entry on successful initialization. The existing startup failure state offers retry and handles synchronous setup errors and rapid asynchronous retry failures. Added bootstrap widget regressions. | `lib/main.dart`, `test/widgets/bootstrap_test.dart` |
| M-06: minimum-version configuration could not be read under default-deny rules | Exposed only the non-sensitive minimum-version value as public read-only. Await the version check and prevent Back from dismissing mandatory-update dialogs. Added read-allowed/write-denied emulator coverage. Outage/cache handling was improved again in section 2. | `database.rules.json`, `lib/splash/splash_page.dart` |
| m-01: trimming changed the user's password | Send passwords unchanged, including leading/trailing spaces. Share the new-password policy and strength feedback across registration/password change; continue accepting existing credentials at login. | registration, login, `lib/profile_pages/change_password_page.dart`, `lib/get_information/password_policy.dart` |
| m-02: provider callers could bypass UI validation | Centralized provider-side validation for ownership, phone/record keys, amounts, descriptions, dates, categories, modes, and transaction types before writes. | `lib/utils/input_validator.dart`, financial providers and entry/edit forms |
| m-03: raw exception/stack logging could disclose paths or identifiers | Removed raw friend-provider exception/stack logging and replaced those failure messages with user-safe errors. This is targeted hardening, not a claim that all production observability has been implemented. | `lib/providers/friend_provider.dart`, associated UI failure handling |
| m-04: analysis/tests were inconclusive; no reliable release checks | Completed local analyzer/tests and added pinned-SDK CI jobs, bounded run times, coverage, web/Android compilation, emulator rules, dependency auditing, and secret scanning. Excluded Node dependency sources from Dart analysis. Remote CI execution remains unverified. | `.github/workflows/qa.yml`, `analysis_options.yaml`, `package.json`, `package-lock.json` |
| m-05: missing security, money-conservation, and failure-path coverage | Added rules authorization/schema/atomicity cases, 10,000 randomized paise-conservation cases, uncertain-write/restart tests, forged-session rejection, and startup failure tests. Kept existing provider/widget/export/stress coverage. Device-level scenarios remain release gates. | `test/firebase/`, `test/utils/money_test.dart`, `test/security/`, `test/services/retry_safe_writer_test.dart`, `test/widgets/bootstrap_test.dart` |

### Additional first-pass changes

- Export sharing uses in-memory files rather than relying on temporary-file
  persistence and supplies tablet share positioning. CSV cells are quoted; the
  sanitizer itself was corrected after the re-audit identified its escaping bug.
- Account deletion reauthenticates before removing history and uses atomic
  database cleanup. Recovery across separate Auth/database services was improved
  further during the production-hardening pass.
- Android disables ordinary automatic backup and explicitly excludes private
  app data from backup/device-transfer rules in
  `android/app/src/main/res/xml/backup_rules.xml` and `data_extraction_rules.xml`.
- `.gitignore` excludes Node dependencies and emulator logs; `firebase.json`
  configures local database rules/emulator testing. No credentials were added to
  the change log or committed by this work.
- Removed obsolete custom-hashing tests; updated session/export expectations
  to match Firebase authentication, secure metadata caching, and decimal money.
- README and in-app terms were revised to remove misleading custom-hashing,
  plaintext-fallback, hardware-security, and universally guaranteed offline claims.
- Added offline ownership-migration preparation and dependency overrides; the
  migration tool and vulnerable dependency resolution were refined later.
- Formatting accompanies some touched Dart files; formatting is not a new feature.

First-pass recorded verification: analyzer clean; offline enforced-lockfile
dependency resolution passed; 87 Flutter tests and 10 emulator rules tests passed;
Node audit reported zero vulnerabilities at that time; debug Android and release
web compilation passed. The re-audit subsequently found additional gaps and a
new development-dependency advisory. Final results are in section 3.

## 2. Re-audit and bug-only production hardening — 1 October 2026

The re-audit identified 13 Major and eight Minor findings, with no confirmed
Critical finding in that review's scope. The following records the solution or
scope-constrained correction, not an unconditional production certification.

| Finding | Remediation and reason |
| --- | --- |
| M-01: CSV sanitization | Corrected the raw regex; neutralizes leading whitespace/control characters and dangerous formula prefixes without altering ordinary descriptions. Added formula-prefix and ordinary-text regressions. Actual spreadsheet import/re-save behavior still needs a supported-app smoke test. |
| M-02: large totals | Separated input and aggregate parsing bounds, retained integer paise in friend/category aggregation, and made unsupported `Money.sum` totals fail explicitly instead of silently becoming zero. Tested the previously failing 1.2-trillion total. This does not provide unlimited-precision accounting. |
| M-03: retry collisions/replay | Explicit form intent IDs, durable original payload journals, UID-scoped keys, and immutable server receipts distinguish separate purchases and acknowledge uncertain commits without overwriting later edits/deletions. Matching old receipts from reopened forms prompt ledger review, not false acknowledgement of a new purchase. |
| M-04: unbounded save UI | Save acknowledgement is bounded at 15 seconds. A timeout retains the same ID and the still-running operation lock; it does not cancel the network write or automatically create a duplicate. Existing forms show pending/retry messages and can leave the busy state. |
| M-05: registration rollback | Removed broad Auth deletion after local cache/UI errors. Remote provisioning is resumable through sign-in, and cache failure is separate from successful account creation. |
| M-06: partial deletion | Atomically scrub financial roots and install a minimal ownership/deletion tombstone before Auth deletion. Same-UID retries remain authorized; queued writes cannot resurrect deleted history. Privacy wording now discloses the retained minimal marker. |
| M-07: orphan-history adoption | Rules deny profile-only deletion and deny new profile claims over orphan financial roots. Replacement of a clean deletion tombstone requires empty financial roots. Migration refuses unreconciled orphan data. |
| M-08: draft cleanup | Persist the save intent with the UID-bound draft before commit; bound and isolate local draft cleanup from the acknowledged transaction outcome. Stale acknowledged drafts are not offered for resubmission. Debounced drafts cannot cross account boundaries. |
| M-09: legacy owed edits | Normalize supported legacy `Owed to ...` values before populating the existing edit form so description edits do not convert debt into online spending. |
| M-10: iOS target | Raised all three Runner deployment targets to iOS 15.0, matching the installed Firebase plugins. Archive/simulator verification on macOS is still required. |
| M-11: split consistency | Persist `split_id`, recognize known legacy key relationships, reject independent financial edits, and atomically delete linked expense/debt branches. Whole-friend deletion is blocked while linked splits remain. Existing confirmations explain whole-bill deletion; financial corrections use delete/re-enter, not a new editor. Arbitrary historical records without recoverable links require reconciliation. |
| M-12: Node audit | Updated the vulnerable gRPC development dependency via a targeted override and regenerated the lockfile. The resolved Node tree reports zero known vulnerabilities at verification time; this is not a full Flutter/native supply-chain attestation. |
| M-13: misleading cash balance | Renamed existing cash/online/total balance displays and exports to ledger-net terminology and clarified terms. The existing model tracks personal consumption/debt, not actual wallet/bank cashflow. A true cashflow model is deliberately not introduced under the no-new-feature constraint. |
| m-01: server dates | Rules validate canonical Gregorian dates, century leap-year exceptions, exact calendar metadata/epoch, and the server's current-date allowance. Writers supply this metadata; invalid/future/inconsistent dates have emulator regressions. |
| m-02: feedback acknowledgement | Feedback uses the same retry-safe writer. Pending/failed delivery retains content and does not show confirmed thanks. Removed the legacy unbound plaintext queue importer and normalized failure messages. |
| m-03: version policy | Cache the last verified minimum version and enforce it when refresh fails. An unavailable first-launch policy asks for retry rather than bypassing the check. Backend rules enforce schema/ownership, not trust in client version claims. |
| m-04: timing gate | Keep correctness assertions in the normal suite; run the unchanged timing thresholds separately with `FINTRACK_BENCHMARKS=true` and concurrency one. Added an isolated CI performance job instead of loosening limits. |
| m-05: ISO offsets | Validate the original calendar components before UTC conversion so valid cross-midnight offsets are accepted while impossible dates are rejected. |
| m-06: large-font split UI | Use Wrap/Flexible, safe-area scrolling, and bounded confirmation sheets on the existing page. Regression covers a 360×640 viewport at text scale 2. |
| m-07: stream failures | Existing friend-detail page now distinguishes synchronization errors from an empty ledger and provides retry. |
| m-08: trip payment mode | Removed the hard-coded online mode and reused the existing Cash/Online selection for the trip save. One mode applies to the trip; mixed-mode bills must be entered as separate trips. No per-bill mixed-payment feature was added. |

Additional account-cache hardening binds cached profiles and drafts to Auth UID,
not just a reusable phone identifier. Remote profile responses are discarded if
the active UID changes while awaiting them, and edited profile caches retain
their owner UID.

### Main implementation areas for the second pass

- Money/date/export correctness: `lib/utils/money.dart`, `ledger_totals.dart`,
  `date_helper.dart`, `input_validator.dart`, expense/friend providers,
  `lib/services/export_service.dart`, `lib/widgets/edit_expense_modal.dart`.
- Retry/save/draft lifecycle: `lib/services/retry_safe_writer.dart`,
  `lib/user_pages/add_spent.dart`, `lib/friends_pages/add_friend_spent.dart`,
  `split_bill_page.dart`, `lib/profile_pages/feedback_page.dart`.
- Split edits/deletion: `lib/services/split_integrity.dart`, financial providers,
  `lib/user_pages/passbook_page.dart`, friend detail/list screens and confirmations.
- Account ownership/provisioning/deletion: `database.rules.json`, authentication
  screens, `lib/user_pages/profile.dart`, session manager, user provider and terms.
- Version/stream/UI feedback: `lib/services/minimum_version_policy.dart`, splash,
  specific-friend page, split form, dashboard labels, export labels and terms.
- Platform/tooling/regressions: `ios/Runner.xcodeproj/project.pbxproj`, Node manifests,
  `.github/workflows/qa.yml`, `tool/prepare_owner_migration.mjs`, and rules, retry,
  migration, stress and production-hardening tests.

## 3. Final verification before documentation cleanup

All tests use synthetic fixtures/local emulators. The full suite includes the
targeted regressions; counts below must not be added as independent total cases.

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | Passed, no issues |
| `flutter test --no-pub --reporter expanded` | 109 passed, zero failures |
| `flutter test test/stress/app_stress_test.dart --no-pub --concurrency=1 --dart-define=FINTRACK_BENCHMARKS=true` | 14 passed on final source in an isolated rerun after compilation; original timing limits retained |
| `npm run test:rules` | 17 passed, zero failures; `demo-fintrack-audit` database emulator only |
| `npm run test:migration` | 5 passed, zero failures; offline synthetic exports |
| `npm audit --audit-level=moderate` | Zero reported vulnerabilities in the resolved Node dependencies |
| `flutter build web --release --no-pub` | Passed on final application source; output `build/web`, 177.4 seconds |
| `flutter build appbundle --release --no-pub` | Passed on final application source; output `build/app/outputs/bundle/release/app-release.aab`, 61.3 MB, 173.3 seconds |
| Android signing | Final rebuilt AAB signature verified; non-debug certificate; no detected weak signing algorithm |
| `git -c core.whitespace=cr-at-eol diff --check` | Passed after documentation changes; only normal Git CRLF warnings |

Earlier hardening-pass AAB SHA-256 (superseded by the cleanup build in section 8):
`844455B15E87B1DB7A982B97D2B10262B718EA671B4D5E79E5D6121661F5851B`.

Coverage includes decimal/large-total math, CSV/JSON/PDF export generation,
ordinary expense/friend/split flows, debt editing, widget navigation/forms,
large fonts, minimum-version outage/cache behavior, save timeouts, acknowledgement
loss, cleanup/storage failures, separate identical purchases, restart recovery,
cross-user/anonymous access, UID recycling, orphan ownership, account cleanup
retry, immutable receipts, future/invalid dates, atomic split rejection/deletion,
and migration rejection of invalid or conflicting history.

Injected failures prove the tested state machine, not every platform's secure
storage or Firebase SDK offline behavior. No real phone airplane-mode/process-death
test, live Auth provisioning/deletion test, screen-reader certification, spreadsheet
formula-execution test, sustained production load test, or macOS iOS archive was
performed. CI configuration was updated, but no remote CI run was certified.

## 4. Required before production deployment

1. Follow the migration procedure in section 5: securely back up data,
   independently verify phone-to-UID ownership, review the offline migration patch,
   reconcile invalid/orphan/unlinked history, and exercise the rollout in staging.
   Coordinate compatible app, date/receipt metadata, stricter rules, and minimum
   version cutover. Reconcile older pending client journals/SDK queues first.
2. A Firebase administrator must verify enumeration protection, the matching
   password policy, endpoint quotas, abuse/billing alerts, and monitoring. Evaluate
   App Check separately in staging. These are not changes to local files and were
   not applied here. See the [Firebase security checklist](https://firebase.google.com/support/guides/security-checklist)
   and [password policy documentation](https://firebase.google.com/docs/auth/flutter/password-auth).
3. Smoke-test Android and any supported iOS devices: sign-in/provisioning retry,
   deletion retry and recreation, account switching, airplane mode/reconnect,
   process death during save, storage failures, large text/orientation/screen
   readers, whole-split corrections, cash trip saves, and export/share cancellation.
   First launch requires a verified version policy; subsequent outages enforce
   the verified cached policy. Firebase queued writes and server acknowledgement
   are different states: [offline capabilities](https://firebase.google.com/docs/database/flutter/offline-capabilities).
4. Run iOS simulator/archive checks on macOS before shipping iOS; source target
   alignment alone does not establish that it builds or runs.
5. Confirm Play Console upload-key matching and secure keystore custody/recovery.
   If `2.2.0+8` is already published, assign an approved new build number. Rebuild
   any APK intended for distribution; older APKs in the workspace were not refreshed.

## 5. Migration, account recovery, and release procedure

### Ownership and ledger migration

The updated rules require `user_details/<phone>/owner_uid`. New registrations
write it. Existing accounts must be migrated before rules cutover, or they can
receive permission-denied errors. Keep registration closed during the coordinated
migration/application rollout.

1. Securely export and back up the database and Firebase Auth users.
2. Independently verify each legacy phone-to-UID mapping. A client claiming a
   phone identifier, or a synthetic email alone, is not ownership proof.
3. Prepare a private JSON object such as `{ "9876543210": "confirmed-auth-uid" }`.
4. Run `npm run test:migration`, then
   `node tool/prepare_owner_migration.mjs <database-export.json> <confirmed-owner-map.json>`.
   It prints an offline multi-path patch and never connects to or writes Firebase.
5. Review the patch and inferred splits. It canonicalizes valid amount/mode/date
   fields, adds calendar metadata, and backfills known split links and operation
   receipts. Invalid/future records, orphan roots, missing mappings, and ownership
   conflicts stop preparation rather than producing a partial patch.
6. Reconcile discrepancies without silently discarding history. The tool cannot
   reconstruct arbitrary relationships from descriptions or repair missing split
   branches. Scrubbed tombstones still need independently verified old ownership;
   do not substitute a new UID merely because the old Auth account was deleted.
7. Validate in staging, then have an authorized administrator apply the reviewed
   patch and coordinate compatible application, minimum-version policy, and rules.
   Do not deploy stricter rules alone: old clients lack new calendar metadata.
8. Drain or reconcile previously shipped pending journals and Firebase SDK offline
   queues before cutover. UID-scoped retry keys do not automatically migrate old
   unbound secure-storage journals. Preserve reviewed backups and protect the
   export, mapping, and patch as private financial/account data.

Legacy `total_get`/`total_give` values are not authoritative; the application derives
balances from records. Normalize supported `Owed to ...` legacy modes to `Owed`.
Calendar validation uses Gregorian dates from 2000 onward, with exact UTC-midnight
metadata and a UTC+14 current-calendar-day allowance. Unchanged valid legacy
dates can remain during edits to other fields.

### Deletion and identity assumptions

Deletion reauthenticates, atomically clears financial roots and installs a scrubbed
ownership/deletion marker, then requests Auth deletion. If Auth deletion fails,
the same UID can retry. Pending-deletion accounts cannot add financial history;
a later UID can replace the marker only when all financial roots are empty.
Minimal UID/phone ownership information is intentionally retained. Complete
identity erasure requires a separate administrator-reviewed retention decision.

Phone numbers are account identifiers, not proof of SMS possession. Verified
Phone Auth would be a separate product/security change, not part of these fixes.

### Signing, authentication settings, and device checks

Use a dedicated release/upload keystore and private `android/key.properties`
configuration. Credentials and keystores must remain outside version control.
The final AAB passed non-debug certificate/signature checks; Play Console key
matching, recovery, and key custody still require release-owner verification.
The application version remains `2.2.0+8`; approve a new build number if already
published. Existing APK files were not rebuilt by the final AAB/web verification.

An administrator must configure/verify enumeration protection, the matching
12-character password policy, appropriate Identity Toolkit quotas, monitoring,
and budget/abuse alerts. Client cooldowns cannot provide server enforcement.
Evaluate App Check in staging before enforcement. These settings were not applied
by editing this repository.

Run real-device checks for sign-in, logout, provisioning/deletion retry, identifier
reuse, account switching, offline/reconnect, app kill during saves, secure-storage
failure, screen readers, large fonts, orientation, split corrections, trip mode,
and export/share cancellation. User-selected PDF/CSV/JSON exports are plaintext
private backups. Test iOS on macOS before shipping it. Local unit/widget tests
cannot certify hardware storage guarantees or production performance.

## 6. Scope and residual limitations

The fix intentionally uses existing phone-keyed roots plus immutable UID ownership
checks; there is no wholesale data-model migration to UID roots. A minimal deletion
marker is retained. Split financial editing uses delete/re-enter. Cash/online values
are ledger nets, not reconciliation with real wallets or banks. Mixed-mode trips
are not modeled. Extremely large totals beyond the defined safe aggregate bound
are unsupported; do not market unlimited precision. Whole-history reads and
receipt retention should be monitored as datasets grow; pagination/archival would
be a separate product change.

Owner-authorized clients can delete their own records; these rules are not a
tamper-proof financial bookkeeping or regulatory audit system. No new backend
coordinator, identity verification method, compliance guarantee, or deployment
was introduced. Legacy records with broken links and old queued writes still need
operator reconciliation before release.

## 7. Documentation cleanup

Consolidated the audit history, final results, and deployment procedure here.
Removed these five non-README project Markdown files:

- `TEST_AND_AUDIT_REPORT.md`
- `POST_FIX_TEST_AUDIT_REPORT.md`
- `PRODUCTION_READINESS.md` (renamed and expanded into this file)
- `DEPLOYMENT_SECURITY.md`
- `LINKEDIN_POST.md`

Preserved root `README.md` and
`ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md`. Updated root README
links to point here. This cleanup does not alter application code or invalidate
the recorded code/build checks; it is not a fresh execution of those tests.

## 8. Final release review and safe cleanup — 1 October 2026

### Release verdict

Local code checks support proceeding to staging verification, not unconditional
public production release. Existing release gates in sections 4–5 still apply:
ownership/legacy-data migration and coordinated rules rollout, administrator Auth
and abuse settings, real-device verification, Play upload-key/build-number checks,
and macOS archive verification if shipping iOS. No production deployment or
Firebase configuration change was performed during this review.

The subsequent Chrome attempt launched the app against local demo Auth/database
emulators and seeded only synthetic test accounts. Interactive computer control
stopped because it could not reliably verify the current Chrome URL. The browser
test suite never progressed beyond loading and was cancelled before cleanup;
there is no verified Chrome end-to-end result. Compilation and VM widget tests
must not be described as completed Chrome interaction tests.

### What was removed and why

| Item | Reason / protection |
| --- | --- |
| Direct `path_provider` declaration | Application/test sources do not import it after memory-based export sharing. It remains in the lockfile as a transitive requirement of another package; required dependencies were not forcibly removed. |
| Cupertino font candidate: retained after verification | Direct source search found no `CupertinoIcons` references, but a release build proved Flutter framework controls still refer to that font family. Restored the dependency to avoid missing glyphs; only the obsolete template comment was clarified. This demonstrates why dependency removal must be verified by builds, not imports alone. |
| `tool/chrome_qa.dart` | Temporary local browser-test entry point, not a production app entry point. Removed after the incomplete Chrome session; normal `lib/main.dart` remains unchanged. |
| `tool/chrome_qa_fixture.mjs` | Temporary synthetic emulator seeding/snapshot script; not needed for deployment. The supported migration preparation tool and all regression tests remain. |
| Generated diagnostics | Removed 117 old diagnostic logs and the two empty Android Kotlin error directories after checking exact workspace targets, then removed the one regenerated emulator log after verification: 118 log files total. Original logs are not recoverable through this cleanup; new runs can generate fresh diagnostics. |

The two temporary QA files were newly generated for that test session, not user
application code. They can be recreated if a future isolated browser run is
needed. The local emulator and temporary QA launcher were stopped. Production
browser sessions, signing credentials, supported-platform directories, source,
image assets, Node test dependencies, Flutter build caches, and release artifacts
were preserved. Analyzer reports no unused imports or dead-code warnings, so
working imports/features were not deleted merely to make the project smaller.

README's cashflow-reconciliation and zero-inconsistency claims were corrected:
the app exposes ledger nets and atomic linked writes, not verified wallet balances
or universal bookkeeping guarantees. No new page or feature was introduced.

### Verification after cleanup

| Check | Latest result |
| --- | --- |
| Offline dependency resolution and enforced lockfile | Passed; no unrelated package versions upgraded |
| Static analysis | No issues found on final dependency graph |
| Full Flutter VM unit/widget/regression suite | 109 passed, zero failures |
| Strict isolated performance suite | 14 passed after release compilation, unchanged thresholds |
| Demo database rules emulator | 17 passed, zero failures; no production writes |
| Offline migration fixtures | 5 passed, zero failures |
| Node dependency audit | Zero reported vulnerabilities |
| Final web release | Passed in 240.7 seconds; missing-font warning resolved; Wasm dry run passed |
| Final Android release AAB | Passed in 206.2 seconds, 61.3 MB |
| Public AAB signature/certificate checks | Verified; non-debug signing; no detected weak signing algorithm |
| Tracked credential filename check | No tracked keystore, signing properties, service-account key, or `.env` path found; not a full secret scan |
| Diff whitespace / temporary helper removal | Passed |
| Chrome end-to-end, physical-device checks, remote CI, iOS archive, production Firebase settings/migration | Not verified; remain release gates |

Current release output: `build/app/outputs/bundle/release/app-release.aab`.
The rebuilt artifact has the same SHA-256 as the prior hardening build because
the effective runtime dependency versions and application source are unchanged:
`844455B15E87B1DB7A982B97D2B10262B718EA671B4D5E79E5D6121661F5851B`.

### Reviewer rating

These are subjective engineering-review scores, not certification, CVSS, or
measured accessibility/coverage percentages.

| Area | Rating | Basis |
| --- | --- | --- |
| Functional/data integrity | 8/10 | Decimal, split, retry, edit and deletion regressions pass; real-device lifecycle remains unverified. |
| Repository security controls | 8/10 | Ownership/schema rules, secure metadata, immutable receipts and signing guards are improved; production settings are not certified. |
| Testing/verification | 8/10 | Broad unit/widget/emulator/migration coverage; Chrome end-to-end, live Auth and hardware tests remain incomplete. |
| Maintainability | 7.5/10 | Shared validation/helpers and cleaner dependencies; complex client write recovery and whole-history reads still require care. |
| Operational release readiness | 5/10 | Migration/settings/device/store/iOS gates have not been demonstrated complete. |

Overall project engineering rating: **8/10**, qualified by the outstanding release
gates. Do not interpret this score as permission to skip them.

## 9. Physical-device test attempt — stopped for recovery

An Android 13 phone was detected with FinTrack already installed. An opt-in QA
package and integration-test harness were prepared, intended to avoid replacing
that installation. The first generated debug APK nevertheless had the production
application ID, not the intended `.qa` suffix. The runtime package guard rejected
the test before Firebase initialization or any scripted account/ledger operations.
Flutter integration-test cleanup uninstalled the phone's FinTrack package. This
was an unintended destructive test-harness failure, not a passing device test.
Local application data may have been removed; recovery has not been established.
No account/financial operations or production deployment were performed by the
test. Device testing was stopped, and the test's USB forwarding was removed.

The generated QA APK/install identity must be inspected BEFORE installation on
any future run, and Flutter's default uninstall behavior must be disabled.
Do not use the new device harness until it is corrected and the user has chosen
the recovery path. The user's existing release AAB remains in the workspace.
Physical-device verification and production release approval are still pending.

## 10. Restarted physical-device attempt — recovery permission required

The user authorized restarting phone testing. The signed production APK was
built, its exact package and signature inspected, and it was successfully
reinstalled with `adb install -r` (without a deliberate uninstall). This does not
prove any previously removed local data was recovered.

Fixed a confirmed password bug: login, registration and change-password fields
were limited to 64 characters although the policy advertises/supports 128.
All six fields now allow 128. Three new widget regressions pass. Static analysis
was clean and the complete local Flutter suite passed **112 tests**. The normal
signed release APK compiled successfully; switching build modes requires plugin
metadata regeneration rather than relying on stale `--no-pub` registrants.

The emulator config was moved to the project root so database rules resolve
correctly, and dedicated free localhost ports were selected. QA build identity
now derives from the explicit integration entry point, with fake native Firebase
configuration applied after Android variant registration. The built QA APK was
successfully inspected as `com.vishalnakum.fintrack.qa`, label `FinTrack QA`, with
demo-only native Firebase resources.

However, running `flutter test -d` rebuilt a **different** APK from its generated
temporary `flutter_test_listener.../listener.dart`, not that inspected entry
point. That rebuild used the production package. Flutter automatically removed
the restored signed app after a signature mismatch and installed the debug test
build, despite `--no-uninstall` (which only disables end-of-test cleanup). The
runtime guard rejected it before scripted account/ledger operations. This was
another test-harness failure, not a passing application test. Phone functionality
and recovery remain unverified; no release approval is given.

Device mutation was stopped. Restoring the signed app requires explicit user
permission to remove the mismatched debug test package first; no such removal
has been performed in this stopped attempt. The signed release APK remains at
`build/app/outputs/flutter-apk/app-release.apk`.

To prevent a repeat, Android builds now reject Flutter's generated test listener.
The runner was changed to freeze a package/backend-verified QA APK and use
`flutter drive --use-application-binary --keep-app-running`, avoiding a second
build. This replacement runner has **not been executed or device-validated**.
Do not describe it as a passing device test.

## 11. Authorized recovery and emulator-only release verification

The user authorized recovery and continued bug fixing. The mistaken phone debug
APK was fingerprinted against the known local test binary before removal. The
normal signed APK's package and certificate were verified. The first reinstall
was blocked by Android's USB-install restriction; the retry already in progress
completed successfully. The user then chose **emulator-only testing**. No further
phone changes or physical-phone feature tests were performed. Reinstallation
does **not** establish recovery of previously removed local data.

### Problems corrected in the QA workflow and documentation

| Problem | Correction and reason |
| --- | --- |
| Flutter's Android test command rebuilt a temporary listener with the production package. | Reject that listener in Gradle; inspect and freeze the QA APK; install only `.qa` with `adb install -r`; attach with `flutter drive --use-existing-app --keep-app-running`. There is no uninstall fallback. The earlier section 10 replacement-runner description is superseded by this attach-only workflow. |
| A stale QA APK could be described as a different test. | Embed its integration-test entry point in a QA-only Android resource and check it before installation, including `-SkipBuild`. |
| Installation could start before Android boot completed. | Wait for `sys.boot_completed`; fail without installing if Android is not ready. |
| Rules fixtures ignored the configured emulator endpoint. | Respect `FIREBASE_DATABASE_EMULATOR_HOST`; reject non-loopback endpoints and non-demo project IDs before destructive fixtures run. Separate the rules-test namespace from native application fixtures. |
| Native emulator routing opened duplicate persistent database repositories and hit an SQLite lock. | Configure the QA-only loopback database URL directly instead of repeatedly applying `useDatabaseEmulator`; retain native persistence for meaningful offline/restart tests. Production Firebase routing is unchanged. |
| QA processes and preview Android system services died under resource pressure. | Bound Gradle/Kotlin worker memory; stop idle compilation workers before device tests; use a separate QA AVD with the already-installed Android 36.1 image, software graphics and a 720×1280 display. The existing Pixel_8 AVD was only run read-only and was not wiped. |
| README recommended anonymous sign-in, cross-user authenticated reads and public feedback writes. | Replace those insecure examples with default-deny setup, Email/Password Auth, UID ownership, the actual repository rules, and explicit migration/staging rollout prerequisites. No production rules were deployed. |

Native test results are saved under `build/device-qa/`. The first passing native
test was run on the **Android 36.1 QA emulator**, not the connected Android 13
phone: demo Firebase connectivity, startup and login-field smoke checks passed.
Security rules: **17 passed** in the isolated rules namespace. Offline migration:
**5 passed**. Node dependency audit: **0 reported vulnerabilities**. These checks
are not proof that production Firebase configuration or physical hardware is
ready. Expanded acceptance/restart results are recorded below after execution.

### Additional confirmed UI fixes

The Android 36.1 native run reproduced registration footer and password-strength
text overflow at approximately 274 logical pixels. The registration/login brand
and footer now wrap without changing their actions, and strength guidance uses
available width. Narrow-screen regressions also reproduced an unbounded
change-password mismatch label; it now wraps beside its icon. All **9 password
field / narrow-screen tests** pass, including 1.8× text size. These are layout
corrections to existing pages, not new features.

Repeated-entry diagnostics found that the QA helper retained Flutter's cached
`focusedEditable` after unfocusing. Re-entering the same confirmation field did
not reopen its input connection. The helper now resets that cached target and
asserts exact controller input. This was a **test-harness defect**, not evidence
that the production registration handler failed.

## 12. Production migration plan — NOT executed

At this stage, the user explicitly chose **prepare the plan only; do not change
production**. No production data backup, ownership migration, rule deployment,
Auth-settings change, or release publication was performed at that stage. The
later, separately authorized startup-only permission repair is recorded in
section 13; the full migration below remains unexecuted.

Read-only checks on `account-flutter-58a59` found:

- Deployed database rules still authorize profiles/ledgers by synthetic email,
  not confirmed `owner_uid`, and omit the new immutable write-receipt schema.
- There is no deployed public-read `app_config/min_version` rule. An unauthenticated
  request to that exact startup-policy endpoint returned **HTTP 401, Permission
  denied**. A fresh hardened client cannot establish a verified policy under
  those rules; this is a deployment blocker, not an emulator test failure.
- Email/Password sign-in and improved email privacy were returned as enabled.
  No custom password-policy configuration was returned. Other absent fields
  (including anonymous sign-in) are not being interpreted as verified disabled.

Required staged rollout, for an administrator to approve and execute later:

1. Choose a new semantic version and a Play version code greater than the latest
   published value. Source currently declares `2.2.0+8`; reusing that semantic
   version prevents a minimum-version gate from distinguishing older 2.2.0
   clients. Do not guess the store's highest version code.
2. In a controlled maintenance window, retain the current signed release, deployed
   rules and a restorable encrypted database backup outside Git/CI artifacts.
   Confirm restore integrity and restrict access to these financial records.
3. Produce a verified phone-to-Firebase-UID ownership map from trusted account
   records, reconcile duplicates/orphans/deleted accounts, and obtain explicit
   ownership confirmation where ambiguous. Never infer ownership only from a
   client-written phone field or silently assign disputed data.
4. Run the existing **offline-only** `tool/prepare_owner_migration.mjs` with that
   private database export and confirmed owner map. Capture its financial-data
   output privately, not in public terminal/CI logs. Review every multi-path
   update, totals, dates and classifications; resolve all rejected legacy data
   before proceeding. The script itself never connects to Firebase.
5. Restore the reviewed data into a separate staging project; apply the patch and
   the repository's `database.rules.json` there. Test existing/new accounts,
   ownership denial, offline reconnect, immutable retry receipts, linked splits,
   exports, session recovery and account deletion with the final signed build.
   Compare account counts and exact-paise totals before and after migration.
6. Configure a compatible server password policy and verify abuse controls,
   API restrictions, quotas and alerts. Do not enforce App Check until compatible
   client integration has been independently verified. Keep email privacy on.
7. Coordinate distribution/upgrade of the compatible signed client and a reviewed
   public-read, server-write-only minimum-version policy. Older clients may not
   understand new schemas or the upgrade gate; explicitly plan their cutoff.
8. After authorization and staging sign-off, pause conflicting old-client writes,
   take a final backup, apply the reviewed production patch and rules, then verify
   startup-policy access, UID ownership, totals, retries and a synthetic-account
   smoke flow. Record deployed rule revision and app artifact hash. None of this
   step is currently authorized.
9. Monitor failures and reconciliation metrics during rollout. Roll back using the
   reviewed compatible rules/client/data plan, preserving post-migration writes;
   never blindly restore a stale backup over new financial entries or reopen
   insecure rules as an emergency workaround.

At that stage, release approval was withheld for the startup deployment blocker
and remaining native/physical-device/store checks. Section 13 resolves only the
startup permission blocker; it does not complete the migration or release gates.

## 13. Authorized startup-version permission repair — 1 October 2026

### Cause and scope

Chrome/mobile startup asks Firebase for `app_config/min_version` before login.
The live rules denied that public request (HTTP 401), while the application
reported every failure as **Connection required**. The user then explicitly
authorized fixing this issue. This supersedes the earlier no-production-write
constraint **only for this startup-policy permission repair**, not for the
ownership/data migration, other rules, Auth settings, or release publication.

### Corrections applied

- Backed up the current live rules and mechanically added only
  `app_config/min_version/.read: true` and `.write: false`. All existing user-data
  rules were preserved exactly. The offline-only helper
  `tool/prepare_startup_policy_patch.mjs` refuses an open root or a writable
  configuration ancestor and never overwrites its rollback input.
- Validated the exact patch in the separate `demo-fintrack-startup-policy`
  emulator namespace before publishing. The generic Firebase deploy command
  failed while fetching project details and did not publish. The authenticated
  Firebase rules REST endpoint, through `firebase database:set /.settings/rules`,
  then applied the verified startup-only artifact successfully.
- Read back the deployed rules and compared them structurally with the intended
  patch: exact match. **No user records were read/exported, migrated, or changed.**
  No account was created, no password/Auth setting was changed, and no phone
  installation was performed.
- The live minimum-version value was already **unset** and remains unset. No
  new version cutoff was guessed or written. A successful absent-setting read
  retains the app's existing no-minimum behavior (`0.0.0`); denied/failed reads
  still require a verified cached policy or a retry, not a silent bypass.
- Added typed version-check failures for permission denial, invalid configuration,
  network/timeout, and unknown failure. The existing dialog now explains the
  actual problem. Failed cache reads no longer hide the original diagnosis.
  Cached minimum-version enforcement and non-dismissible startup gating remain.
- Added an explicitly opted-in, read-only Chrome public-policy check. Ordinary
  test runs/CI skip production access. It uses a GET-only browser request and the
  same version-policy resolver, not a production account or financial-data flow.
  No new page or user feature was introduced.

### Verified results

- Startup-only rules tests: **4 passed**, including unauthenticated reads of
  absent/present policy, authenticated/unauthenticated write denial, unchanged
  unrelated rules, and private-path/parent-configuration denial.
- Flutter alert/policy and existing hardening regressions: **23 passed**.
- Live public `GET /app_config/min_version.json`: **HTTP 200**, value `null`.
- Live public parent-config and synthetic private-path reads: **HTTP 401**.
- Live anonymous write probe repeating the existing `null` setting: **HTTP 401**;
  the policy value remained unchanged.
- Opted-in Chrome public-policy request and version-policy resolution: **1 passed**.
- Full local Flutter unit/widget/stress-functional suite: **131 passed, 1 skipped**
  in 57 seconds. The skipped case is the explicitly opted-in live browser request,
  which passed separately in Chrome. JSON results are saved under
  `build/startup-policy-20261001/flutter-tests.json`. This is not a new strict
  performance benchmark run or native end-to-end acceptance pass.
- Final static analysis: **no issues**. Formatting and whitespace checks passed.

### Browser verification limits and temporary test workaround

The installed Windows Flutter test server returned 404 for existing CanvasKit
assets because its URL/file-path handling uses inconsistent separators. Serving
temporary copies of the SDK's two Chromium CanvasKit assets under
`test/canvaskit/chromium/` made those requests return 200. A separate dispatch
error dropped separators from nested test paths, so the opted-in browser test is
kept at the test root. **The SDK itself was not modified.** The temporary copies
and their empty directories were removed after testing; SDK originals remain.
On this Windows SDK, reproduce the opted-in Chrome check only with that local
asset-serving workaround or a corrected SDK test runner.

The attempted full Login startup test did not pass: a live test binding stalled,
and a later browser-harness attempt timed out during Firebase initialization.
These attempts are not counted as successful application UI tests. The passing
Chrome test is deliberately narrower: an unauthenticated browser GET of the
exact public policy URL followed by the real version-policy resolver. The
permission/configuration dialogs are covered by the passing widget tests.
Physical-mobile and full production Login/financial flows remain unverified.

Verified rollback snapshots are retained in ignored
`.release-backups/startup-policy-20261001/`, outside routine build cleanup and Git.
The deployment/test artifacts also remain under `build/startup-policy-20261001/`.
Before reverting rules, compare the then-current live rules with
`production-rules-after.json`; do not overwrite subsequent administrator changes
blindly. Snapshot hashes:

- Before: `4E906AF9509D9F3E1D6A15BFB45CC0AFC4BE59CEFCED466BD28A68A7729CF077`
- After: `3865AD42AFB2912CB0D0E6C708A402F35D9481F2DE6C6084AD4B098DC02BF2B7`

The startup access blocker is resolved. Full production readiness is still
withheld: the separately planned UID/schema migration and remaining end-to-end,
restart, physical-device and release checks are not completed by this repair.
