import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/nav_bar.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String appVersion = "0.0.0";

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

  Future<void> getDecision() async {
    final bool hasValidSession = await SessionManager.isSessionValid();
    final String? phoneNumber = await SessionManager.getPhoneNumber();

    if (!mounted) return;

    if (hasValidSession && phoneNumber != null && phoneNumber.isNotEmpty) {
      context.read<UserProvider>().loadUserSession();
      context.read<ExpenseProvider>().fetchExpenses(phoneNumber);
      context.read<FriendProvider>().fetchFriends(phoneNumber);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const NavPageSelector()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getVersion();
    Future.delayed(const Duration(milliseconds: 2200), () {
      getDecision();
    });
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
