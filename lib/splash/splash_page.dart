import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/nav_bar.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:firebase_database/firebase_database.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String appVersion = "1.0.0";

  Future<void> getVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          appVersion = packageInfo.version;
        });
      }
    } catch (_) {}
  }

  bool _isVersionLower(String current, String minimum) {
    try {
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final mParts = minimum.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (cParts.length < 3) {
        cParts.add(0);
      }
      while (mParts.length < 3) {
        mParts.add(0);
      }
      for (int i = 0; i < 3; i++) {
        if (cParts[i] < mParts[i]) return true;
        if (cParts[i] > mParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  void _showUpdateDialog(String minVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xff0D8A3F)),
            SizedBox(width: 8),
            Text("Update Required"),
          ],
        ),
        content: Text(
          "A newer version of FinTrack (v$minVersion) is required. Please update the app to continue using it.",
        ),
      ),
    );
  }

  Future<void> getDecision() async {
    try {
      final results = await Future.wait([
        SessionManager.isSessionValid().timeout(const Duration(seconds: 3), onTimeout: () => false),
        SessionManager.getPhoneNumber().timeout(const Duration(seconds: 3), onTimeout: () => null),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);

      if (!mounted) return;

      // Check minVersion from Firebase Realtime Database
      try {
        final versionSnap = await FirebaseDatabase.instance
            .ref('app_config/min_version')
            .get()
            .timeout(const Duration(seconds: 2));
        if (versionSnap.exists && versionSnap.value != null) {
          final minVer = versionSnap.value.toString().trim();
          if (_isVersionLower(appVersion, minVer)) {
            if (mounted) {
              _showUpdateDialog(minVer);
              return;
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;

      final bool hasValidSession = results[0] as bool;
      final String? phoneNumber = results[1] as String?;

      final currentUser = FirebaseAuth.instance.currentUser;
      final expectedEmail = '$phoneNumber@fintrack.app';

      if (hasValidSession &&
          phoneNumber != null &&
          phoneNumber.isNotEmpty &&
          currentUser != null &&
          currentUser.email == expectedEmail) {
        context.read<UserProvider>().loadUserSession();
        context.read<ExpenseProvider>().fetchExpenses(phoneNumber);
        context.read<FriendProvider>().fetchFriends(phoneNumber);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NavPageSelector()),
        );
        return;
      } else if (hasValidSession) {
        // Clear stale local session on auth mismatch
        await SessionManager.clearSession();
      }
    } catch (_) {
      await SessionManager.clearSession();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    getVersion();
    getDecision();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF8),

      body: Center(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // Logo
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Image.asset(
                    "assets/image/AccountApplicationLogo.jpg",
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                "FinTrack",
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0D8A3F),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Manage Your Money Smartly",
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 40),

              const CircularProgressIndicator(color: Color(0xff0D8A3F)),

              const Spacer(),

              Text(
                "Version $appVersion",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),

              const SizedBox(height: 25),

              Text(
                "© 2026 Vishal Nakum",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),

              const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}
