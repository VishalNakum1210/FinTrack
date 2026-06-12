import 'package:account/authantication/login_page.dart';
import 'package:account/user_pages/main_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashPage extends StatefulWidget {
  @override
  State<SplashPage> createState() => _splash_Page();
}

class _splash_Page extends State<SplashPage> {
  Future<void> getDecition() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String? phoneNumber = sp.getString("phone_number");
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => UserMainPage()),
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
    getDecition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF8BC24A),),
      ),
    );
  }
}
