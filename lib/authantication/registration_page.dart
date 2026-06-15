import 'package:account/authantication/login_page.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';

class RegistrationPage extends StatefulWidget {
  @override
  State<RegistrationPage> createState() => _RegistrationStatePage();
}

class _RegistrationStatePage extends State<RegistrationPage> {
  TextEditingController Control_name = TextEditingController();
  TextEditingController Control_email = TextEditingController();
  TextEditingController Control_phone = TextEditingController();
  TextEditingController Control_password = TextEditingController();

  bool isLoading = false;

  void check_details() async {
    String name = Control_name.text;
    String phone_number = Control_phone.text;
    String email = Control_email.text;
    String password = Control_password.text;

    if (name.isEmpty ||
        phone_number.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill all fields");
      return;
    } else if (phone_number.length != 10) {
      Fluttertoast.showToast(msg: "Enter valid phone number");
      return;
    } else if (!email.contains("@")) {
      Fluttertoast.showToast(msg: "Enter valid email");
      return;
    } else {
      setState(() {
        isLoading = true;
      });
      try {
        final myRef = FirebaseDatabase.instance.ref(
          'user_details/$phone_number',
        );
        DatabaseEvent event = await myRef.once();

        if (event.snapshot.value != null) {
          Fluttertoast.showToast(msg: "Phone Number Already exsist");
        } else {
          await register_details(name, phone_number, email, password);
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Database is not connected : $e");
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> register_details(
    String name,
    String phone_number,
    String email,
    String password,
  ) async {
    try {
      final myRef = FirebaseDatabase.instance.ref("user_details");

      await myRef.child(phone_number).set({
        "name": name,
        "phone_number": phone_number,
        "email": email,
        "password": password,
      });

      Fluttertoast.showToast(msg: "Registration Successful");
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
    } catch (e) {
      Fluttertoast.showToast(msg: "Not Connected $e");
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Background
            Container(color: Colors.white),

            // Green Circle
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

            // Main Scrollable Content
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 70,
                left: 20,
                right: 20,
                bottom: 30,
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello",
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Welcome Back!",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),

                      Container(
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
                    ],
                  ),

                  const SizedBox(height: 50),

                  // Registration Card
                  Container(
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
                        const Text(
                          "Register Account",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8BC24A),
                          ),
                        ),

                        const SizedBox(height: 30),

                        TextField(
                          controller: Control_name,
                          decoration: inputDecoration("Name"),
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: Control_email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: inputDecoration("Email"),
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: Control_phone,
                          keyboardType: TextInputType.phone,
                          decoration: inputDecoration("Phone Number"),
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: Control_password,
                          obscureText: true,
                          decoration: inputDecoration("Password"),
                        ),
                        Container(
                          width: double.infinity,
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            child: Text("User Already Exsists"),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              check_details();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8BC24A),
                            ),
                            child: const Text(
                              "Submit",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              Container(
                height: double.infinity,
                width: double.infinity,
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF8BC24A),),
                )
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8BC24A)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          width: 3,
          color: Color.fromARGB(255, 74, 127, 61),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: const BorderSide(width: 3, color: Color(0xFF8BC24A)),
      ),
    );
  }
}
