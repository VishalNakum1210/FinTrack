import 'dart:async';
import 'package:fin_track/get_information/hash_password.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/nav_bar.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';

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
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  int failedAttempts = 0;
  Timer? _throttleTimer;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _throttleTimer?.cancel();
    super.dispose();
  }

  int _getPasswordStrength(String pass) {
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 6) score++;
    if (pass.length >= 8 && RegExp(r'[a-zA-Z]').hasMatch(pass) && RegExp(r'[0-9]').hasMatch(pass)) score++;
    if (pass.length >= 10 && RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass)) score++;
    return score;
  }

  Future<void> checkDetails() async {
    if (failedAttempts >= 5) {
      Fluttertoast.showToast(msg: "Too many attempts. Please wait before trying again.");
      return;
    }

    String name = nameController.text.trim();
    String phoneNumber = phoneController.text.trim();
    String email = emailController.text.trim().toLowerCase();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty ||
        phoneNumber.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill all fields");
      return;
    }

    if (phoneNumber.length != 10 || int.tryParse(phoneNumber) == null) {
      Fluttertoast.showToast(msg: "Please enter a valid 10-digit phone number");
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      Fluttertoast.showToast(msg: "Please enter a valid email address");
      return;
    }

    if (!isPasswordStrong(password)) {
      Fluttertoast.showToast(
        msg: "Password must be at least 6 characters and contain letters & numbers or symbols",
      );
      return;
    }

    if (password != confirmPassword) {
      Fluttertoast.showToast(msg: "Passwords do not match");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: "$phoneNumber@fintrack.app",
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        try {
          await user.updateDisplayName(name);
        } catch (_) {}
        try {
          DatabaseReference ref = FirebaseDatabase.instance.ref("user_details/$phoneNumber");
          final snapshot = await ref.get().timeout(const Duration(seconds: 8));
          if (snapshot.exists && snapshot.value is Map) {
            final existing = Map<String, dynamic>.from(snapshot.value as Map);
            await ref.update({
              "name": name,
              "phone_number": phoneNumber,
              "email": email.isNotEmpty ? email : (existing["email"] ?? ""),
              "address": existing["address"] ?? "Not Entered",
            });
          } else {
            await ref.set({
              "name": name,
              "phone_number": phoneNumber,
              "email": email,
              "address": "Not Entered",
              "created_at": ServerValue.timestamp,
            });
          }

          await SessionManager.saveSession(
            phoneNumber: phoneNumber,
            username: name,
            email: email,
          );

          if (mounted) {
            context.read<UserProvider>().loadUserSession();
            context.read<ExpenseProvider>().fetchExpenses(phoneNumber);
            context.read<FriendProvider>().fetchFriends(phoneNumber);
          }

          Fluttertoast.showToast(msg: "Registration Successful! Welcome to FinTrack.");
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const NavPageSelector()),
            (route) => false,
          );
        } catch (dbError) {
          await userCredential.user?.delete();
          Fluttertoast.showToast(msg: "Failed to create profile. Please check connection and retry.");
        }
      }
    } on FirebaseAuthException catch (e) {
      failedAttempts++;
      if (failedAttempts >= 5) {
        _throttleTimer?.cancel();
        _throttleTimer = Timer(const Duration(seconds: 30), () {
          if (mounted) setState(() => failedAttempts = 0);
        });
      }
      if (e.code == 'email-already-in-use') {
        Fluttertoast.showToast(msg: "Phone number is already registered! Please login.");
      } else if (e.code == 'weak-password') {
        Fluttertoast.showToast(msg: "Password is too weak. Please use a stronger password.");
      } else if (e.code == 'operation-not-allowed') {
        Fluttertoast.showToast(
          msg: "Email/Password sign-in is disabled in Firebase Console. Please enable it under Authentication > Sign-in method.",
        );
      } else if (e.code == 'network-request-failed') {
        Fluttertoast.showToast(
          msg: "Network error. Please check your internet connection.",
        );
      } else if (e.code == 'too-many-requests') {
        Fluttertoast.showToast(
          msg: "Too many attempts. Please wait a moment before trying again.",
        );
      } else if (e.code == 'invalid-email') {
        Fluttertoast.showToast(
          msg: "Please enter a valid 10-digit phone number.",
        );
      } else {
        Fluttertoast.showToast(msg: e.message ?? "Registration failed");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Unable to complete setup. Please check connection and retry.");
      failedAttempts++;
      if (failedAttempts >= 5) {
        _throttleTimer?.cancel();
        _throttleTimer = Timer(const Duration(seconds: 30), () {
          if (mounted) setState(() => failedAttempts = 0);
        });
      }
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
      counterText: "",
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
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
                            maxLength: 50,
                            textInputAction: TextInputAction.next,
                            decoration: inputDecoration("Full Name"),
                          ),

                          const SizedBox(height: 18),

                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            maxLength: 100,
                            textInputAction: TextInputAction.next,
                            decoration: inputDecoration("Email"),
                          ),

                          const SizedBox(height: 18),

                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textInputAction: TextInputAction.next,
                            decoration: inputDecoration("Phone Number"),
                          ),

                          const SizedBox(height: 18),

                          TextField(
                            controller: passwordController,
                            obscureText: !isPasswordVisible,
                            maxLength: 64,
                            textInputAction: TextInputAction.next,
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

                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: passwordController,
                            builder: (context, val, _) {
                              final pass = val.text;
                              if (pass.isEmpty) return const SizedBox.shrink();
                              final strength = _getPasswordStrength(pass);
                              final color = strength <= 1
                                  ? Colors.red
                                  : strength == 2
                                      ? Colors.orange
                                      : const Color(0xFF8BC24A);
                              final label = strength <= 1
                                  ? "Weak"
                                  : strength == 2
                                      ? "Medium"
                                      : "Strong";

                              return Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: strength / 3.0,
                                          backgroundColor: Colors.grey.shade200,
                                          color: color,
                                          minHeight: 5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 14),

                          TextField(
                            controller: confirmPasswordController,
                            obscureText: !isConfirmPasswordVisible,
                            maxLength: 64,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => isLoading ? null : checkDetails(),
                            decoration: inputDecoration(
                              "Confirm Password",
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isConfirmPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF8BC24A),
                                ),
                                onPressed: () {
                                  setState(() {
                                    isConfirmPasswordVisible = !isConfirmPasswordVisible;
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
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginPage(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),

                          const Padding(
                          padding: EdgeInsets.only(top: 14, bottom: 6),
                          child: Text(
                            "By registering, you agree to FinTrack's Terms of Service and Privacy Policy.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: Colors.black54),
                          ),
                        ),

                        const SizedBox(height: 16),

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
    ),
  );
}
}
