# 🚀 LinkedIn Post: FinTrack v2.1 Major UI & Architecture Overhaul

*Copy and paste the text below directly into your LinkedIn post, then attach `screenshots/fintrack_screen_recording.mp4`!*

---

Excited to unveil a major UI & architectural transformation for **FinTrack** (v2.1) — a modern, high-performance personal finance & split-ledger mobile app built with **Flutter** and **Firebase**! 💚💸

Most expense trackers only log what you spend, but real life is collaborative. Whether it's splitting dinner with colleagues or tracking who paid for the weekend trip, managing money across accounts and friends often turns into messy spreadsheets or mental math.

We re-engineered FinTrack from the ground up with a clean Material Design 3 fintech aesthetic, double-entry ledger mathematics, and offline-first resilience.

Here is a breakdown of what’s new in this release 👇

---

### 🎨 1. Modern UI/UX Overhaul
- **Emerald Fintech Palette**: A sleek, high-contrast Material 3 theme crafted for readability and elegance.
- **Dual-Wallet Architecture**: Instant separation between liquid **Cash in Hand** and **Bank / Online** balances for accurate cashflow reconciliation.
- **Interactive Sparklines**: Visual balance trajectory curves showing financial momentum over time.
- **Paginated Passbook**: Smooth 50-item chunk loading, dynamic category chips, and zero-jank chronological sorting.

---

### ⚡ 2. Core Feature Upgrades
- 👥 **Double-Entry Friend Ledger**: Live real-time streaming listeners displaying mutual debt balances (**"You Get"** vs **"You Owe"**) with 1-tap debt settlement.
- 🍕 **Atomic Multi-Friend Bill Splitting**: Split group expenses evenly across any number of friends in a single transaction — automatically updating your personal passbook and each friend’s ledger simultaneously without discrepancies.
- 📊 **Visual Analytics & Health Score**: Integrated **FL Chart** interactive grouped bar charts (Inflow vs Outflow), category donut charts, and an algorithmic **Financial Health Score (0–100%)**.
- 📄 **1-Click Multi-Format Export Engine**: Generate printable **Vector PDF Statements** with custom date ranges, **CSV Spreadsheets** ready for Excel/Sheets, and full **JSON Cloud Backups**.

---

### 🛡️ 3. Security & Engineering Rigor
- 🔒 **1,000-Round Salted HMAC-SHA256**: Key-stretched password protection running in dedicated Dart `compute()` background isolates to keep the UI at a buttery 60/120 FPS.
- 🔐 **Hardware-Backed Session Security**: Sessions encrypted via Android Keystore / iOS Keychain (`flutter_secure_storage`).
- 📶 **10MB Offline Disk Cache**: Full offline functionality with automatic, conflict-free cloud sync upon reconnection.
- 🧪 **51 Automated Tests**: 100% test coverage across cryptographic hashing, balance arithmetic, export generators, and navigation back-stack logic.
- 📦 **Optimized Release Builds**: Pre-built Android APKs split by ABI (`arm64-v8a` ~21 MB).

---

🎥 **Watch the 30-second walkthrough video attached to see the app in action!**

The project is completely open source on GitHub:
👉 **Repository**: https://github.com/VishalNakum1210/FinTrack

Would love to hear your thoughts, feedback, and suggestions in the comments! If you like the project, feel free to drop a ⭐ on GitHub!

---

#Flutter #Firebase #Dart #MobileAppDevelopment #UIUXDesign #Fintech #OpenSource #CleanArchitecture #FlutterDev #AndroidDev #SoftwareEngineering
