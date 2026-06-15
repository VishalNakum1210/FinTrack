import 'package:account/GetInformation/GetTotalExpenses.dart';
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
  String? name, totalExpanses;

  Future<void> getDetails() async {
    SharedPreferences sp = await SharedPreferences.getInstance();

    String? total = await getTotalExpenses(
      sp.getString("phone_number")!,
    );

    setState(() {
      name = sp.getString("username") ?? "";
      totalExpanses = total;
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
              margin: const EdgeInsets.only(bottom: 5, right: 10),
              height: 50,
              width: 50,
              child: const CircleAvatar(
                radius: 25,
                backgroundImage: AssetImage(
                  "assets/image/AccountApplicationLogo.jpg",
                ),
              ),
            ),
            Text("Welcome, ${name ?? ''}"),
          ],
        ),
        backgroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        child: Container(
          color: const Color(0xFF8BC24A),

          child: Stack(
            children: [
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    margin: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Text(
                        "₹ ${totalExpanses ?? '0'}",
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  Container(
                    height: 400,
                    padding: const EdgeInsets.only(
                      bottom: 10,
                      top: 10,
                    ),
                    margin: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: 50,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFE4D5A3),
                    ),

                    child: ListView.builder(
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(
                            left: 10,
                            right: 10,
                            bottom: 10,
                          ),
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              Positioned(
                bottom: 50,
                child: Container(
                  height: 60,
                  width: 100,
                  padding: const EdgeInsets.all(10),
                  child: ElevatedButton(
                    onPressed: () {
                      Fluttertoast.showToast(msg: "Clicked");
                      logout();
                    },
                    child: const Text("Logout"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddSpent(),
            ),
          );

          if (result == true) {
            getDetails();
          }
        },
        backgroundColor: Colors.white,
        child: Image.asset(
          "assets/image/GreenPlus.png",
          height: 30,
          width: 30,
        ),
      ),
    );
  }
}