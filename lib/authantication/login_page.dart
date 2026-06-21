import 'package:account/GetInformation/HashPassword.dart';
import 'package:account/authantication/registration_page.dart';
import 'package:account/nav_bar.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController username = TextEditingController();
  TextEditingController password = TextEditingController();

  bool isLoading = false;

  void check_user_details() async {
    String phone_number = username.text;
    String password_user = password.text;

    if (phone_number == "" || password_user == "") {
      Fluttertoast.showToast(msg: "Enter All Requried Details");
      return;
    }
    if (phone_number.length != 10) {
      Fluttertoast.showToast(msg: "Invalid Phone number !!!");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final MyRef = FirebaseDatabase.instance.ref("user_details/$phone_number");
      DatabaseEvent event = await MyRef.once();

      if (event.snapshot.value != null) {
        Map values = event.snapshot.value as Map;
        password_user = hashPassword(password_user);
        if (password_user == values["password"]) {
          Fluttertoast.showToast(msg: "Login successfully");
          await Save_data(values["name"], phone_number, values["email"]);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => NavPageSelector()),
          );
        } else {
          Fluttertoast.showToast(msg: "Wrong Password !!!");
        }
      } else {
        Fluttertoast.showToast(msg: "User Don't exsists !!!");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Database Not Connected $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> Save_data(String username, String phone_number, String email) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.setString("username", username);
    await sp.setString("phone_number", phone_number);
    await sp.setString("email", email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(color: Colors.white),

          // Big green/yellow circle
          Positioned(
            top: -180,
            left: -80,
            child: Container(
              width: 600,
              height: 700,
              decoration: const BoxDecoration(
                color: Color(0xFF8BC24A),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Welcome text
          Positioned(
            top: 80,
            left: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Hello",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  "Welcome Back!",
                  style: TextStyle(
                    fontSize: 18,
                    color: const Color.fromARGB(255, 74, 127, 61),
                  ),
                ),
              ],
            ),
          ),

          // Logo
          Positioned(
            top: 70,
            right: 30,
            child: Container(
              height: 100,
              width: 100,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
              ),
              child: Image.asset(
                'assets/image/AccountApplicationLogo.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Login Card
          Positioned(
            top: 220,
            left: 20,
            right: 20,
            child: Container(
              height: 500,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 15,
                    color: Colors.black12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 50),
                    child: Text(
                      "Login Account",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8BC24A),
                      ),
                    ),
                  ),

                  Container(
                    margin: EdgeInsets.only(top: 70),
                    child: TextField(
                      style: TextStyle(color: Color(0xFF8BC24A)),
                      controller: username,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hint: Text(
                          "Phone Number",
                          style: TextStyle(color: Color(0xFF8BC24A)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            width: 3,
                            color: const Color.fromARGB(255, 74, 127, 61),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(
                            width: 3,
                            color: Color(0xFF8BC24A),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Container(
                    margin: EdgeInsets.only(top: 20),
                    child: TextField(
                      style: const TextStyle(color: Color(0xFF8BC24A)),
                      controller: password,
                      obscureText: true,
                      decoration: InputDecoration(
                        hint: Text(
                          "Password",
                          style: TextStyle(color: Color(0xFF8BC24A)),
                        ),
                        // hintText: "Password",
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            width: 3,
                            color: const Color.fromARGB(255, 74, 127, 61),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(
                            width: 3,
                            color: Color(0xFF8BC24A),
                          ),
                        ),
                      ),
                    ),
                  ),

                  InkWell(
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Text("User Don't Exsists"),
                    ),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegistrationPage(),
                        ),
                      );
                    },
                  ),

                  Container(
                    width: double.infinity,
                    height: 50,
                    margin: EdgeInsets.only(top: 70),
                    child: ElevatedButton(
                      onPressed: () {
                        check_user_details();
                      },
                      child: Text(
                        "Submit",
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF8BC24A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF8BC24A)),
              ),
            ),
        ],
      ),
    );
  }
}
