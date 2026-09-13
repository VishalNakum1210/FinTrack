import 'dart:async';
import 'package:fin_track/get_information/hash_password.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/authentication/registration_page.dart';
import 'package:fin_track/nav_bar.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;

  // Brute-force protection
  int failedAttempts = 0;
  int lockoutSeconds = 0;
  Timer? lockoutTimer;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    lockoutTimer?.cancel();
    super.dispose();
  }

  void startLockoutTimer() {
    setState(() {
      lockoutSeconds = 30;
    });
    lockoutTimer?.cancel();
    lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (lockoutSeconds > 1) {
            lockoutSeconds--;
          } else {
            lockoutSeconds = 0;
            failedAttempts = 0;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> checkUserDetails() async {
    if (lockoutSeconds > 0) {
      Fluttertoast.showToast(
        msg: "Too many failed attempts. Please wait $lockoutSeconds seconds.",
      );
      return;
    }

    String phoneNumber = username.text.trim();
    String passwordUser = password.text.trim();

    if (phoneNumber.isEmpty || passwordUser.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter all required details");
      return;
    }
    if (phoneNumber.length != 10) {
      Fluttertoast.showToast(msg: "Please enter a valid 10-digit phone number");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final myRef = FirebaseDatabase.instance.ref("user_details/$phoneNumber");
      DatabaseEvent event = await myRef.once();

      bool isAuthenticated = false;

      if (event.snapshot.value != null && event.snapshot.value is Map) {
        Map values = event.snapshot.value as Map;
        String storedPassword = (values["password"] ?? "").toString();

        if (await verifyPasswordAsync(passwordUser, storedPassword, phoneNumber)) {
          isAuthenticated = true;

          // Transparently upgrade legacy hashes to hardened v3
          if (!storedPassword.startsWith("v3_")) {
            await myRef.update({
              "password": await hashPasswordAsync(passwordUser, phoneNumber),
            });
          }

          failedAttempts = 0;
          await SessionManager.saveSession(
            phoneNumber: phoneNumber,
            username: (values["name"] ?? "").toString(),
            email: (values["email"] ?? "").toString(),
          );

          if (mounted) {
            context.read<UserProvider>().loadUserSession();
            context.read<ExpenseProvider>().fetchExpenses(phoneNumber);
            context.read<FriendProvider>().fetchFriends(phoneNumber);
          }

          Fluttertoast.showToast(msg: "Login successful");
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NavPageSelector()),
          );
        }
      }

      if (!isAuthenticated) {
        failedAttempts++;
        if (failedAttempts >= 5) {
          startLockoutTimer();
          Fluttertoast.showToast(
            msg: "Too many failed attempts. Locked for 30 seconds.",
          );
        } else {
          // Anti-enumeration: Generic message
          Fluttertoast.showToast(
            msg: "Invalid phone number or password (${5 - failedAttempts} attempts remaining)",
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Database connection failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF8BC24A)),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          width: 2,
          color: Color.fromARGB(255, 74, 127, 61),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          width: 2.5,
          color: Color(0xFF8BC24A),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative background circle
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

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Header with welcome text and logo
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
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            "Welcome Back!",
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

                  const SizedBox(height: 40),

                  // Login Card
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            "Login Account",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8BC24A),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        TextField(
                          controller: username,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.black87),
                          decoration: inputDecoration("Phone Number"),
                        ),

                        const SizedBox(height: 20),

                        TextField(
                          controller: password,
                          obscureText: !isPasswordVisible,
                          style: const TextStyle(color: Colors.black87),
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
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegistrationPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Don't have an account? Sign Up",
                              style: TextStyle(
                                color: Color.fromARGB(255, 74, 127, 61),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (isLoading || lockoutSeconds > 0) ? null : checkUserDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8BC24A),
                              disabledBackgroundColor: Colors.grey.shade400,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              lockoutSeconds > 0
                                  ? "Locked (${lockoutSeconds}s)"
                                  : "Submit",
                              style: const TextStyle(
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
          ),

          if (isLoading)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF8BC24A)),
              ),
            ),
        ],
      ),
    );
  }
}
