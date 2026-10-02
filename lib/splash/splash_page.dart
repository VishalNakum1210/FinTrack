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
import 'package:fin_track/services/minimum_version_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Color _brandGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF2E7D32);
  static const Color _canvasBackground = Color(0xFFF8FAFC);
  static const Color _primaryText = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);

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
    return MinimumVersionPolicy.isLower(current, minimum);
  }

  void _showUpdateDialog(String minVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: _darkGreen),
              SizedBox(width: 10),
              Text(
                "Update Required",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _primaryText,
                ),
              ),
            ],
          ),
          content: Text(
            "A newer version of FinTrack (v$minVersion) is required. Please update the app from the store to continue.",
            style: const TextStyle(
              fontSize: 14,
              color: _mutedText,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: const Text(
                "Exit App",
                style: TextStyle(color: _mutedText),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _darkGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                getDecision();
              },
              child: const Text("Check Again"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> getDecision() async {
    try {
      final results = await Future.wait([
        SessionManager.isSessionValid().timeout(
          const Duration(seconds: 3),
          onTimeout: () => false,
        ),
        SessionManager.getPhoneNumber().timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        ),
        Future.delayed(const Duration(milliseconds: 900)),
      ]);

      if (!mounted) return;

      try {
        final minimum = await MinimumVersionPolicy.resolve(
          remote: () async {
            final snapshot = await FirebaseDatabase.instance
                .ref('app_config/min_version')
                .get()
                .timeout(const Duration(seconds: 8));
            return snapshot.exists ? snapshot.value.toString().trim() : '0.0.0';
          },
          cached: () async => (await SharedPreferences.getInstance()).getString(
            'verified_min_version',
          ),
          cache: (value) async {
            await (await SharedPreferences.getInstance()).setString(
              'verified_min_version',
              value,
            );
          },
        );
        if (_isVersionLower(appVersion, minimum)) {
          if (mounted) _showUpdateDialog(minimum);
          return;
        }
      } catch (error) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => VersionCheckFailureDialog(
            failure: VersionPolicyException.from(error),
          ),
        );
        if (mounted) await getDecision();
        return;
      }

      if (!mounted) return;

      final bool hasValidSession = results[0] as bool;
      final String? phoneNumber = results[1] as String?;

      final currentUser = FirebaseAuth.instance.currentUser;
      final expectedEmail = '$phoneNumber@fintrack.app';

      final isEmailMatch = currentUser != null &&
          currentUser.email != null &&
          currentUser.email!.toLowerCase().trim() ==
              expectedEmail.toLowerCase().trim();
      final isPhoneMatch = currentUser != null &&
          currentUser.phoneNumber != null &&
          currentUser.phoneNumber!.replaceAll(RegExp(r'\D'), '').endsWith(
                phoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '___',
              );

      if (hasValidSession &&
          phoneNumber != null &&
          phoneNumber.isNotEmpty &&
          (isEmailMatch || isPhoneMatch)) {
        context.read<UserProvider>().loadUserSession();
        context.read<ExpenseProvider>().fetchExpenses(phoneNumber);
        context.read<FriendProvider>().fetchFriends(phoneNumber);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const NavPageSelector()),
        );
        return;
      } else if (hasValidSession &&
          currentUser != null &&
          !isEmailMatch &&
          !isPhoneMatch) {
        // Clear stale local session on verified auth mismatch
        await SessionManager.clearSession();
        await FirebaseAuth.instance.signOut();
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
    getVersion().then((_) {
      if (mounted) getDecision();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBackground,
      body: Center(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // FinTrack Logo Container with soft modern elevation
              Container(
                height: 88,
                width: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: _brandGreen.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    "assets/image/AccountApplicationLogo.jpg",
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Brand Title
              const Text(
                "FinTrack",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _primaryText,
                  letterSpacing: -0.6,
                ),
              ),

              const SizedBox(height: 8),

              // Tagline
              const Text(
                "Smart Expense Tracking & Split Ledgers",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _mutedText,
                ),
              ),

              const SizedBox(height: 18),

              // Trust & Security Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFA5D6A7),
                    width: 0.8,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, color: _darkGreen, size: 13),
                    SizedBox(width: 5),
                    Text(
                      "256-Bit Encrypted • Realtime Sync",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _darkGreen,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 38),

              // Loading Spinner
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(_brandGreen),
                ),
              ),

              const Spacer(flex: 3),

              // Version Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "v$appVersion",
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Copyright
              const Text(
                "© 2026 Vishal Nakum",
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keep startup blocked until a verified policy is available, without calling
/// a server configuration failure an internet outage.
class VersionCheckFailureDialog extends StatelessWidget {
  final VersionPolicyException failure;

  const VersionCheckFailureDialog({super.key, required this.failure});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: Text(failure.title),
      content: Text(failure.description),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
