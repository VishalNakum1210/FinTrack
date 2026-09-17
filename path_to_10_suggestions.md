# 🏆 FinTrack — Path to 10/10: Suggestions & Solutions

**Current System Average: 8.15 / 10**  
**Target: 10.0 / 10**  
**Strategy: Fix Critical → High → Medium → Polish each page**

> [!IMPORTANT]
> Pages are listed **lowest score first** — fix these first for maximum impact.

---

## 🔴 CRITICAL TIER (Score < 7.0)

---

### 1. `add_friends.dart` — Current: 6.0 → Target: 10.0

**Why it's low:** Two critical data-integrity bugs that can silently destroy user data.

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Ledger Overwrite Bug** — Adding an existing friend calls `.set({})`, which wipes ALL their transaction history and resets balance to zero | Before saving, check if the friend node already exists in Firebase. If it does, show a message like *"Friend already added"* and abort. Switch from `.set()` to `.update()` so only missing fields are written |
| 2 | **Self-Friend Bug** — User can add their own phone number as a friend | Before any Firebase call, compare `enteredPhone == currentUserPhone`. If equal, show *"You cannot add yourself as a friend"* and stop |
| 3 | **No Duplicate Feedback** — User gets no warning when re-adding; it silently overwrites | Show a clear SnackBar/dialog: *"This number is already in your friends list"* |
| 4 | **No Phone Format Hint** — Users don't know if they should enter country code | Add a placeholder like `+91 XXXXXXXXXX` or a prefix selector |
| 5 | **No Loading Skeleton** — Friend lookup shows a spinner with no context | Show a message like *"Looking up contact..."* during the Firebase query |

**Result after fixes: ~9.5 / 10**

---

### 2. `specific_friend_page.dart` — Current: 6.8 → Target: 10.0

**Why it's low:** Inverted tap/long-press UX is dangerous and confusing; memory leak on edit.

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Tap = Delete (inverted UX)** — Single-tap on a transaction card immediately shows *Delete* dialog | Swap: single-tap should show a **detail/edit bottom sheet**. Long-press OR a swipe-to-delete gesture should trigger delete |
| 2 | **Memory Leak** — `TextEditingController`s created inside `_editRecord()` are never disposed | Promote controllers to `State` fields, initialize in `initState()`, dispose in `dispose()` — just like any other form page |
| 3 | **No Edit Confirmation** — After editing a record, there's no toast/snackbar confirmation | Show *"Transaction updated successfully"* after a successful edit |
| 4 | **No Empty State** — When a friend has zero transactions, show a friendly illustration and CTA (*"Add your first transaction"*) | Add an `EmptyState` widget with icon + message |
| 5 | **No Search/Filter** — With many transactions, finding a specific one is impossible | Add a search bar or date-range filter at the top |
| 6 | **Balance Card UX** — The get/owe balance card doesn't animate when values change | Wrap the balance text with `AnimatedSwitcher` or a counting animation |

**Result after fixes: ~9.5 / 10**

---

## 🟠 HIGH TIER (Score 7.0 – 7.9)

---

### 3. `split_bill_page.dart` — Current: 7.2 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Non-Atomic Split** — Each friend is updated in a separate network call. If the app closes mid-loop, some friends are charged and others aren't | Use Firebase's multi-path update (`ref.update({ 'path1': val1, 'path2': val2 })`) in a single call so it's all-or-nothing |
| 2 | **No Retry on Partial Failure** — If one friend's update fails, the bill is partially applied with no way to retry | If the atomic update fails, show an error and keep the form open so user can retry. Never partially pop the screen |
| 3 | **No Per-Person Breakdown in History** — After splitting, there's no way to see *which* bill a transaction came from | Add an optional `billId` metadata field to each created record |
| 4 | **Amount Validation** — Entering `0` or negative amounts is not blocked at the UI level | Add a validator: amount must be > 0 before the Split button is enabled |
| 5 | **No Confirmation Summary Screen** — User has no chance to review before committing | Show a summary sheet (*"You will charge ₹X to each of N friends — Confirm?"*) before executing |

**Result after fixes: ~9.5 / 10**

---

### 4. `passbook_page.dart` — Current: 7.4 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Tap = Instant Delete Dialog** — Single tap on any transaction shows a destructive dialog with no context | Tap should open a **transaction detail card** (amount, category, date, note, payment method). Move delete to a button *inside* that detail view or to a long-press/swipe |
| 2 | **No Swipe-to-Delete Affordance** — There's no visual hint that records can be deleted | Add `Dismissible` widget with a red background + trash icon revealed on swipe-left |
| 3 | **List Performance** — All records are rendered at once even with 1,000+ entries | Use the already-added `_displayLimit` with a scroll listener that auto-loads more as user scrolls (replace "Load More" button with infinite scroll) |
| 4 | **No Empty State per Filter** — Filtering to a category with no records shows a blank screen | Add a friendly message: *"No [Category] transactions found"* |
| 5 | **Sort is Rebuilt Every Frame** — Sorting happens inside `build()` | Move sort logic into the `ExpenseProvider` so it's only recomputed when data changes |
| 6 | **No Edit** — Transactions can only be deleted, never corrected | Add an "Edit" option in the transaction detail view |

**Result after fixes: ~9.5 / 10**

---

### 5. `profile.dart` — Current: 7.4 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **CRITICAL: Data Deleted Before Auth** — `deleteUser()` removes all Firebase Realtime Database records *before* calling `user.delete()`. If Firebase Auth throws `requires-recent-login`, the auth account survives but all data is permanently gone | **Fix order:** First call `user.delete()`. If it throws `requires-recent-login`, show a re-auth dialog. Only delete database records *after* `user.delete()` succeeds |
| 2 | **No Re-Auth Flow** — When `requires-recent-login` is thrown on delete, there's no UI to re-enter password and retry | Add a "Confirm Identity" dialog that collects password, calls `reauthenticateWithCredential`, then retries deletion |
| 3 | **Logout has no Confirmation** — Tapping logout immediately signs out | Show a simple dialog: *"Are you sure you want to log out?"* |
| 4 | **Delete Account has No Cooldown** — No rate-limiting on the delete operation | Disable the delete button for 5 seconds after first tap |
| 5 | **Phone Number Source** — Profile fetches phone from multiple places; should use one source of truth | Always read phone from `SessionManager.getPhoneNumber()` — never from a separate RTDB fetch |

**Result after fixes: ~9.5 / 10**

---

### 6. `friend_provider.dart` — Current: 7.4 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Over-fetching** — `fetchFriends` fetches every transaction record for every friend every time, even for a simple friend-list view | Split the Firebase listener: listen to friend *metadata* only (`/Friends/$phone/$friend/meta/`) for the overview list. Load `Records/` only when a specific friend's page is opened |
| 2 | **Non-Atomic Split Bill** — Two separate `.push()` calls for split bill; one can fail without the other rolling back | Batch into a single multi-path `.update()` |
| 3 | **Force-Unwrap `.key!`** — `atomicSplitBill` still uses `.key!` which crashes if Firebase is offline | Use `ref.push()` which returns a ref with a guaranteed local key — assign `ref.key` before awaiting the write, with a null check fallback |
| 4 | **No Offline Support** — Provider gives no indication when data is stale/offline | Add an `isOffline` flag; subscribe to Firebase's `.info/connected` path and surface it in the UI |
| 5 | **No Pagination for Records** — A friend with 5,000 records downloads all of them at once | Use Firebase's `.limitToLast(50)` query and load earlier records on demand |

**Result after fixes: ~9.5 / 10**

---

### 7. `registration_page.dart` — Current: 7.6 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **No Confirm Password Field** — A single typo during registration permanently locks the user out (no password reset possible with synthetic email domain) | Add a second *"Confirm Password"* field. Only enable the Register button when both fields match |
| 2 | **No Password Reset Flow** — The app uses `$phone@fintrack.app` synthetic emails, so Firebase's email reset doesn't work | Implement a custom reset: verify OTP via SMS/WhatsApp, then call `user.updatePassword()`. Alternatively, add a security question at registration |
| 3 | **Orphaned Auth on RTDB Failure** — If `user.delete()` fails after an RTDB write failure, the auth account is permanently stuck (user can never re-register with that phone) | Implement retry logic: if `user.delete()` fails, store the orphaned UID in SharedPreferences and retry cleanup on next app launch |
| 4 | **Password Strength Meter** — No visual feedback on password complexity | Add a 3-level strength indicator (Weak / Medium / Strong) below the password field using the existing `isPasswordStrong()` logic |
| 5 | **No Terms & Privacy Link** — Registering implies consent, but there's no link to terms | Add a "By registering, you agree to our Terms of Service" line with a link |

**Result after fixes: ~9.5 / 10**

---

### 8. `edit_information_page.dart` — Current: 7.5 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Data Source Inconsistency** — Page loads data from a fresh RTDB call instead of reading from `UserProvider` | Pre-populate all fields from `UserProvider`'s in-memory data — no extra network call needed |
| 2 | **No Dirty State Detection** — Save button is always active, even when nothing was changed | Disable the Save button if the current field values match the original values |
| 3 | **No Field Validation on Submit** — Invalid email can be saved if validation is skipped | Validate all fields on button press before calling `updateInformation()` |
| 4 | **Address Field Too Small** — Address field has no multiline support | Make the Address `TextField` use `maxLines: 3, minLines: 1` for comfortable input |
| 5 | **No Success Animation** — After saving, user is just navigated back with no confirmation | Show a brief success SnackBar *"Profile updated successfully"* before popping |

**Result after fixes: ~9.5 / 10**

---

## 🟡 MEDIUM TIER (Score 8.0 – 8.5)

---

### 9. `login_page.dart` — Current: 8.0 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Auth Zombie State** — If RTDB fetch times out *after* `signInWithEmailAndPassword` succeeds, `signOut()` is never called | After the timeout catch block, always call `FirebaseAuth.instance.signOut()` before showing the error |
| 2 | **No Biometric Login** — Returning users must type their phone + password every time | Integrate `local_auth` package: offer Face ID / Fingerprint after first successful login |
| 3 | **No "Remember Me"** — Session is always 30 days; there's no option | Add a "Stay signed in" checkbox that controls session duration (30 days vs 1 day) |
| 4 | **Error Messages are Generic** — "Login failed" doesn't tell user if the phone is wrong vs password wrong | Map specific `FirebaseAuthException` codes to friendly messages: `user-not-found` → *"No account with this number"*, `wrong-password` → *"Incorrect password"* |
| 5 | **No Password Visibility Toggle** — Password field is always hidden | Add a show/hide eye icon to the password field |

**Result after fixes: ~9.8 / 10**

---

### 10. `change_password_page.dart` — Current: 8.0 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **No Rate Limiting on Failed Re-Auth** — User can brute-force their own account (useful if phone is stolen) | After 3 failed re-auth attempts, lock the form for 5 minutes |
| 2 | **No Confirm New Password Field** — Single password entry for new password risks typos | Add a *"Confirm New Password"* field |
| 3 | **No Password Strength Indicator** | Add the same 3-level strength meter as suggested for Registration |
| 4 | **No Password History Check** — App already guards same-password, but not recent history | Optionally store a hash of the last 3 passwords and warn if reused |
| 5 | **Feedback Delay** — Loading indicator appears, then success navigates without user reading the result | Show a brief *"Password changed successfully"* SnackBar before navigating away |

**Result after fixes: ~9.8 / 10**

---

### 11. `add_friend_spent.dart` — Current: 8.0 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **No Decimal Keyboard on iOS** | Change `TextInputType.number` to `TextInputType.numberWithOptions(decimal: true)` |
| 2 | **No "Split Equally" Quick Action** — User must navigate to a separate screen | Add a quick "Split with [Friend]" button that pre-fills half the amount |
| 3 | **Dropdown Friend Stale Check** — `DropdownMenu` `initialSelection` doesn't verify the friend still exists | When opening the form, validate that the pre-selected friend is still in the friends list |
| 4 | **No Category Icons in Dropdown** — Friend expense categories have no visual differentiator | Add leading category icons to dropdown items |
| 5 | **Success feedback** — No clear confirmation message after saving | Show a SnackBar *"Transaction added for [Friend Name]"* |

**Result after fixes: ~9.5 / 10**

---

### 12. `add_spent.dart` — Current: 8.5 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **iOS Decimal Block** — `TextInputType.number` on iOS blocks decimal input (e.g., ₹150.50 is impossible) | Change to `TextInputType.numberWithOptions(decimal: true)` |
| 2 | **No Smart Category Suggestion** — Category is always manual | Use the last 5 transactions' categories to offer quick-select suggestions at the top of the category list |
| 3 | **No Recurring Transaction Support** — Common expenses (rent, salary) must be re-entered every month | Add a *"Repeat"* toggle (daily/weekly/monthly) using `flutter_local_notifications` |
| 4 | **No Draft Saving** — If user closes mid-form, all input is lost | Auto-save form state to SharedPreferences on every field change; restore on next open |
| 5 | **Date Picker UX** — Date field uses a text input; replace with a `showDatePicker` calendar widget | Tapping the date field should open a system date picker, not free-text |

**Result after fixes: ~9.8 / 10**

---

### 13. `friend_expenses.dart` — Current: 8.2 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **No Search Bar** — With 20+ friends, finding one requires scrolling | Add a search bar at the top that filters the friends list by name or number |
| 2 | **No Sort Options** — Friends are always in insertion order | Add sort options: *Most recent activity*, *Highest balance*, *Alphabetical* |
| 3 | **Net Balance Summary** — No single number showing total money owed/owing across all friends | Add a summary banner at the top: *"You are owed ₹X total across N friends"* |
| 4 | **Swipe to Remove Friend** — Removing a friend requires navigating into their ledger | Add a long-press context menu or swipe action for quick friend removal |
| 5 | **Friend Avatar** — Generic icon for all friends | Use the first letter of the friend's name as a colored avatar (like Google Contacts) |

**Result after fixes: ~9.5 / 10**

---

### 14. `report_page.dart` — Current: 8.2 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Friend Ledger Ignores Date Filter** — The "Friend Ledger Overview" section always shows all-time data even when a weekly/monthly filter is selected | Pass the selected date range into the friend ledger query so it reflects the same period as the charts |
| 2 | **Chart Touch Rebuilds Animation** — Touching a pie/bar chart segment triggers a full `setState`, replaying the entrance animation | Use `AnimationController` with `forward()` only on first load; subsequent data updates should use `animateTo()` |
| 3 | **No Export Button on Report** | Add a "Share Report" button that generates a PDF snapshot of the current analytics page |
| 4 | **Financial Health Score Explanation** — The health score shows a number but doesn't explain the formula | Add an info icon (ⓘ) that opens a tooltip/sheet explaining how the score is calculated |
| 5 | **No Year-Over-Year Comparison** — Only current period vs previous period is shown | Add a toggle to compare the same period across 2 years |

**Result after fixes: ~9.8 / 10**

---

### 15. `main_page.dart` — Current: 8.4 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Pull-to-Refresh Overlap** — The pull-to-refresh spinner overlaps a modal loading indicator | Use only one loading mechanism: either pull-to-refresh *or* the overlay loader, not both simultaneously |
| 2 | **GridView Overflow at High Font Scale** — KPI cards overflow at system font scale > 1.5× | Wrap each KPI card's text with `FittedBox` or use `AutoSizeText` |
| 3 | **No Greeting Personalization** — Shows the same UI regardless of time of day | Add a time-based greeting: *"Good morning, Vishal 🌅"* / *"Good evening 🌙"* |
| 4 | **No Quick Add FAB** — To add a transaction, user must tap NavBar → Add Spent | Add a floating `+` button on the home dashboard that opens `AddSpent` directly |
| 5 | **No Spending Trend Arrow** — Balance card shows current balance but not direction | Add a small ↑/↓ arrow next to the balance showing change vs last week |

**Result after fixes: ~9.8 / 10**

---

### 16. `splash_page.dart` — Current: 8.4 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Hard-coded Delay** — 2200ms wait regardless of session check speed | Run session check and minimum delay in parallel (`Future.wait`) with only 800ms minimum |
| 2 | **Concurrent Secure Storage Reads** — Multiple reads issued simultaneously | Chain reads sequentially, or read once and cache the session map |
| 3 | **Stale Session Not Cleared** — If Firebase Auth says logged out but local session exists, session isn't cleared | On auth mismatch, call `SessionManager.clearSession()` before redirecting to Login |
| 4 | **No Version Mismatch Handling** — App shows splash but never alerts user if version is too old | If the fetched `minVersion` > current version, redirect to an *"Update Required"* screen |
| 5 | **No Lottie/Animated Logo** — Static logo on splash | Replace with a brief Lottie animation (< 1 second) for a polished first impression |

**Result after fixes: ~9.8 / 10**

---

## 🟢 HIGH PERFORMERS (Score 8.5+) — Polish to 10.0

---

### 17. `export_service.dart` — Current: 8.4 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Decimal Parse Bug** — `int.tryParse("150.50")` returns null → ₹0 in PDF | Use `(double.tryParse(value) ?? 0.0).round()` instead of `int.tryParse` |
| 2 | **No Password-Protected PDF** — Exported statements contain full financial data with no protection | Add optional PDF password protection using `pdf` package's encryption support |
| 3 | **No Page Numbers** | Add page `X of Y` footer to all multi-page PDFs |
| 4 | **No App Branding on PDF** — Generic header | Add FinTrack logo, color theme, and tagline to the PDF header |
| 5 | **Large PDF Memory** — Generating PDFs for 1000+ records loads everything in memory first | Stream records in batches of 100 into the PDF builder to prevent OOM on large exports |

**Result after fixes: ~9.8 / 10**

---

### 18. `feedback_page.dart` — Current: 8.6 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **No Category Selection** — All feedback goes to one bucket | Add a category picker: *Bug Report / Feature Request / General Feedback / Complaint* |
| 2 | **No Screenshot Attachment** — Users can't show you the problem visually | Allow attaching a screenshot via `image_picker`, uploaded to Firebase Storage |
| 3 | **No Submission Confirmation Screen** — After submit, user sees a toast and goes back | Show a *"Thank you!"* full-screen confirmation with a fun illustration |
| 4 | **No Offline Queue** — If feedback is submitted offline, it's lost | Queue the payload locally and submit when connectivity resumes |
| 5 | **No Previous Submissions View** — User can't see what they've already reported | Add a "My Feedback" section showing past submissions from RTDB |

**Result after fixes: ~9.8 / 10**

---

### 19. `session_manager.dart` — Current: 8.7 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Clock Rollback Vulnerability** — Negative elapsed time could be used to extend session indefinitely | If `elapsed < 0`, treat it as expired immediately (cap elapsed at 0) |
| 2 | **SharedPreferences Fallback Still Writes** — `updateLastActive()` writes to SharedPreferences unconditionally even when secure storage succeeded | Only write to SharedPreferences as fallback if `FlutterSecureStorage` write throws an exception |
| 3 | **Hardcoded Secret** — `_sessionSecret` is a compile-time constant visible in the binary | Inject via `--dart-define=SESSION_SECRET=...` at build time |
| 4 | **No Session Anomaly Detection** — No check for impossibly fast location change or device fingerprint mismatch | Store a device identifier hash in the session; invalidate if it changes (detects session token theft) |
| 5 | **No Session History** — No audit log of logins | Store last-login timestamp and device info in RTDB `user_details/$phone/lastLogin` |

**Result after fixes: ~9.8 / 10**

---

### 20. `expense_provider.dart` — Current: 8.5 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Realtime Sort in Build** — Some callers still sort `records` inline | Expose a pre-sorted list getter in the provider so no consumer ever needs to sort |
| 2 | **No Offline Optimistic Updates** — Adding a transaction waits for Firebase round-trip before UI updates | Add the new record to the local list immediately (optimistic update), then sync to Firebase in background |
| 3 | **No Transaction Search** — No full-text search across all transactions | Add a `search(String query)` method that filters by description, category, or amount |
| 4 | **No Budget Tracking** | Add monthly category budgets stored in RTDB; expose `isOverBudget(category)` getter |
| 5 | **Currency Precision** — Amounts stored as strings can accumulate floating-point drift | Store all amounts as integer paise (×100) to avoid floating-point precision issues |

**Result after fixes: ~9.8 / 10**

---

### 21. `add_friends.dart` (Scoring continuation from UX gap)

*(Already covered in Critical Tier #1 above)*

---

### 22. `currency_helper.dart` — Current: 8.5 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **Single Currency** — Only supports INR | Add multi-currency support with user-selectable base currency and exchange rate fetch from a free API |
| 2 | **No Compact Notation** — ₹1,50,000 shown in full | Add `compact()` method: ₹1.5L, ₹2.3Cr for display in space-constrained KPI cards |
| 3 | **No Negative Formatting** — Negative amounts shown as `-₹500` instead of styled red `(₹500)` | Add a `formatSigned()` method that returns a colored `TextSpan` |

**Result after fixes: ~9.8 / 10**

---

### 23. `user_provider.dart` — Current: 9.1 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **No Profile Picture Support** — User model has no avatar | Add a `profilePicUrl` field; support uploading via Firebase Storage |
| 2 | **No Cached Offline User** — If Firebase is offline on launch, `UserProvider` shows loading forever | Cache the last-known user profile in SharedPreferences; show cached data while reloading |
| 3 | **No Dark Mode Preference** — User display preferences not persisted in the user model | Add `themeMode` to the RTDB user profile so theme syncs across devices |

**Result after fixes: ~10.0 / 10**

---

### 24. `date_helper.dart` — Current: 9.2 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **No Fast Path for DateTime Input** — `toDateTime()` always processes string conversion even for DateTime inputs | Add `if (dateVal is DateTime) return dateVal;` as the very first line |
| 2 | **No Localization** — Date formats hardcoded for en-IN | Use `intl` package's `DateFormat.yMMMd(locale)` to respect system locale |
| 3 | **No Relative Time** — No "2 days ago" / "just now" display | Add a `toRelative(DateTime date)` method for feed-style displays |

**Result after fixes: ~10.0 / 10**

---

### 25. `database.rules.json` — Current: 9.0 → Target: 10.0

| # | Issue | Suggestion |
|---|---|---|
| 1 | **No Field-Level Validation** | Add `.validate` rules for each field: name max 50 chars, amount must be a number > 0, phone must be 10 digits |
| 2 | **No Write Rate Limiting** | Firebase RTDB doesn't support native rate limiting, but you can add server-side Cloud Functions triggers that reject writes exceeding N/minute per user |
| 3 | **Registration Write Window** | The `!data.exists()` window for unauthenticated registration writes should be as narrow as possible — document this clearly and consider migrating registration to a Cloud Function |

**Result after fixes: ~10.0 / 10**

---

## 📋 Priority Action Matrix

| Priority | Pages to Fix | Est. Gain |
|:---:|---|---|
| **P0 (Do First)** | `add_friends.dart`, `profile.dart` | +3.5 pts (critical bugs) |
| **P1 (Do Second)** | `specific_friend_page.dart`, `passbook_page.dart`, `split_bill_page.dart` | +2.5 pts (UX safety) |
| **P2 (High Value)** | `registration_page.dart`, `login_page.dart`, `change_password_page.dart` | +2.0 pts (auth UX) |
| **P3 (Polish)** | `export_service.dart`, `main_page.dart`, `friend_provider.dart` | +1.5 pts (robustness) |
| **P4 (Nice to Have)** | `currency_helper.dart`, `date_helper.dart`, `feedback_page.dart` | +1.0 pt (completeness) |

---

## 🎯 Target System Score After All Fixes: **9.8 / 10**

> [!NOTE]
> A true 10/10 would require full test coverage (>80%), localization, accessibility (a11y) compliance, multi-currency support, and an end-to-end CI/CD pipeline. These are valid long-term goals beyond the current scope.
