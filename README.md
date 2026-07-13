<div align="center">

# 💰 FinTrack

### Smart Personal Finance Manager

<p>
Track Expenses • Manage Income • Analyze Spending • Friend Ledger
</p>

<img src="screenshots/banner.png" alt="FinTrack Banner" width="100%"/>

<p>

<img src="https://img.shields.io/badge/Flutter-3.32+-02569B?style=for-the-badge&logo=flutter"/>
<img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart"/>
<img src="https://img.shields.io/badge/Firebase-Realtime%20Database-FFCA28?style=for-the-badge&logo=firebase"/>
<img src="https://img.shields.io/badge/Material%203-UI-34A853?style=for-the-badge"/>

</p>

<p>

<img src="https://img.shields.io/badge/Platform-Android-success?style=flat-square"/>
<img src="https://img.shields.io/badge/Status-Active-success?style=flat-square"/>
<img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square"/>

</p>

> **A modern Flutter application for managing personal finances with real-time synchronization, insightful reports, and friend expense tracking.**

</div>

---

# ✨ Why FinTrack?

FinTrack is a modern personal finance application built with **Flutter** and **Firebase Realtime Database**. It helps users effortlessly manage income, expenses, cash, online balances, and shared transactions with friends through a clean and intuitive interface.

---

# 🚀 Key Features

| 💰 Finance | 📊 Analytics | 👥 Friends |
|------------|-------------|------------|
| Income & Expense Tracking | Interactive Reports | Friend Ledger |
| Cash & Online Wallet | Financial Summary | Borrow / Lend Records |
| Transaction History | Charts & Insights | Balance Tracking |

---

# 📱 Application Preview

| Home | Passbook |
|------|-----------|
| ![](screenshots/home1.png) | ![](screenshots/passbook.png) |

| Reports | Friends |
|---------|----------|
| ![](screenshots/reports.png) | ![](screenshots/friends.png) |

| Profile | Add Transaction |
|---------|-----------------|
| ![](screenshots/profile.png) | ![](screenshots/add_transaction.png) |

---

# 🏗 Architecture

```text
        Flutter Application
               │
               ▼
        Business Logic Layer
               │
     ┌─────────┴─────────┐
     ▼                   ▼
SharedPreferences   Firebase RTDB
     │                   │
     └─────────┬─────────┘
               ▼
          Material UI
```

---

# 🔄 Application Flow

```text
Splash
   │
Login / Register
   │
Dashboard
├── Add Expense
├── Passbook
├── Friends
├── Reports
└── Profile
```

---

# 📂 Project Structure

```text
lib/
├── Authentication/
├── FriendsPages/
├── GetInformation/
├── ProfilePages/
├── Splash/
├── UserPages/
├── firebase_options.dart
├── nav_bar.dart
└── main.dart
```

---

# 🛠 Tech Stack

- Flutter
- Dart
- Firebase Realtime Database
- SharedPreferences
- Material Design

---

# 📦 Installation

```bash
git clone https://github.com/YOUR_USERNAME/FinTrack.git

cd FinTrack

flutter pub get

flutter run
```

---

# 📈 Roadmap

- Dark Mode
- Budget Planning
- PDF & Excel Export
- Cloud Backup
- Monthly Goals
- Notifications
- Multi-language Support

---

# 👨‍💻 Developer

**Vishal Nakum**

B.Tech Computer Science Engineering

Flutter Developer

---

<div align="center">

### ⭐ If you like this project, give it a Star!

Made with ❤️ using Flutter & Firebase

</div>