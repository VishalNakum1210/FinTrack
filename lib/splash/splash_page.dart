import 'package:account/authantication/login_page.dart';
import 'package:account/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashPage extends StatefulWidget {
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Future<void> getDecision() async {
    SharedPreferences sp = await SharedPreferences.getInstance();

    String? phoneNumber = sp.getString("phone_number");

    if (!mounted) return;

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => NavPageSelector(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LoginPage(),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    getDecision();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.green,),
        ),
      ),
    );
  }
}