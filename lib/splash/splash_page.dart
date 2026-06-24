import 'package:account/authantication/login_page.dart';
import 'package:account/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SplashPage extends StatefulWidget {
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String appVersion = "0.0.0";

  Future<void> getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      appVersion = packageInfo.version;
    });
  }

  Future<void> getDecision() async {
    SharedPreferences sp = await SharedPreferences.getInstance();

    String? phoneNumber = sp.getString("phone_number");

    if (!mounted) return;

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => NavPageSelector()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getVersion();
    Future.delayed(const Duration(seconds: 5), () {
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
