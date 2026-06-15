import 'package:account/authantication/login_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _profilePage();
}

class _profilePage extends State<ProfilePage> {

  Future<void> logout() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Profile",
          style: TextStyle(
            color: Color(0xFF8BC24A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFE4D5A3),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ElevatedButton(onPressed: () async {await logout();}, child: Text("Logout")),
            )
          ],
        ),
      ),
    );
  }
}
