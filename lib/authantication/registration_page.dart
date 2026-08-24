import 'package:FinTrack/GetInformation/HashPassword.dart';
import 'package:FinTrack/authantication/login_page.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> checkDetails() async {
    String name = nameController.text.trim();
    String phoneNumber = phoneController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (name.isEmpty ||
        phoneNumber.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill all fields");
      return;
    }

    if (phoneNumber.length != 10 || int.tryParse(phoneNumber) == null) {
      Fluttertoast.showToast(msg: "Please enter a valid 10-digit phone number");
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      Fluttertoast.showToast(msg: "Please enter a valid email address");
      return;
    }

    if (!isPasswordStrong(password)) {
      Fluttertoast.showToast(
        msg: "Password must be at least 6 characters and contain letters & numbers",
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final myRef = FirebaseDatabase.instance.ref(
        'user_details/$phoneNumber',
      );
      DatabaseEvent event = await myRef.once();

      if (event.snapshot.value != null) {
        Fluttertoast.showToast(msg: "Phone number is already registered!");
      } else {
        await registerDetails(name, phoneNumber, email, password);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Database connection error: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> registerDetails(
    String name,
    String phoneNumber,
    String email,
    String password,
  ) async {
    try {
      final myRef = FirebaseDatabase.instance.ref("user_details");

      await myRef.child(phoneNumber).set({
        "name": name,
        "phone_number": phoneNumber,
        "email": email,
        "password": hashPassword(password, phoneNumber),
        "Address": "Not Entered",
        "created_at": ServerValue.timestamp,
      });

      Fluttertoast.showToast(msg: "Registration Successful! Please login.");
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to register: $e");
    }
  }

  InputDecoration inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8BC24A)),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          width: 2,
          color: Color.fromARGB(255, 74, 127, 61),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          width: 2.5,
          color: Color(0xFF8BC24A),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Background Circle
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
                top: 30,
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
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Join Us Today!",
                            style: TextStyle(
                              fontSize: 18,
                              color: Color.fromARGB(255, 74, 127, 61),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      Container(
                        height: 75,
                        width: 75,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/image/AccountApplicationLogo.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Registration Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 20,
                          color: Colors.black12,
                          offset: Offset(0, 8),
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

                        const SizedBox(height: 25),

                        TextField(
                          controller: nameController,
                          decoration: inputDecoration("Full Name"),
                        ),

                        const SizedBox(height: 18),

                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: inputDecoration("Email"),
                        ),

                        const SizedBox(height: 18),

                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: inputDecoration("Phone Number"),
                        ),

                        const SizedBox(height: 18),

                        TextField(
                          controller: passwordController,
                          obscureText: !isPasswordVisible,
                          decoration: inputDecoration(
                            "Password",
                            suffixIcon: IconButton(
                              icon: Icon(
                                isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xFF8BC24A),
                              ),
                              onPressed: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            child: const Text(
                              "Already have an account? Sign In",
                              style: TextStyle(
                                color: Color.fromARGB(255, 74, 127, 61),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 25),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : checkDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8BC24A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              "Submit",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
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
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8BC24A)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
