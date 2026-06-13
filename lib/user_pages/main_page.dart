import 'package:account/authantication/login_page.dart';
import 'package:account/user_pages/add_spent.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserMainPage extends StatefulWidget {
  @override
  State<UserMainPage> createState() => _userMainPage();
}

class _userMainPage extends State<UserMainPage> {
  String? name;

  Future<void> getDetails() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    setState(() {
      name = sp.getString("username");
    });
  }

  Future<void> logout() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 5, right: 10),
              height: 50,
              width: 50,
              child: CircleAvatar(
                radius: 25,
                backgroundImage: AssetImage(
                  "assets/image/AccountApplicationLogo.jpg",
                ),
              ),
            ),
            Text("Welcome, $name"),
          ],
        ),
        backgroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        child: Container(
          // height: double.infinity,
          // width: double.infinity,
          color: Color(0xFF8BC24A),

          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    height: 200,
                    margin: EdgeInsets.only(left: 20, right: 20, top: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                  ),

                  Container(
                    height: 400,
                    padding: EdgeInsets.only(bottom: 10, top: 10),
                    margin: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 50),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Color(0xFFE4D5A3),
                    ),

                    child: ListView.builder(
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.only(left: 10, right: 10, bottom: 10),
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Positioned(
                child: Container(
                  height: 60,
                  width: 60,
                  padding: EdgeInsets.all(10),
                  child: ElevatedButton(
                    onPressed: () {
                      Fluttertoast.showToast(msg: "Clicked");
                      logout();
                    },
                    child: Text("Logout"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AddSpent()));
        },
        backgroundColor: Colors.white,
        child: Image.asset("assets/image/GreenPlus.png", height: 30, width: 30),
      ),
    );
  }
}
