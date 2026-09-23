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

  static const Color _brandGreen = Color(0xFF8BC24A);
  static const Color _canvasBackground = Color(0xFFF8FAFC);
  static const Color _primaryText = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

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

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      counterText: "",
      filled: true,
      fillColor: _canvasBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          width: 1.2,
          color: _borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          width: 1.8,
          color: _brandGreen,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          width: 1.2,
          color: Color(0xFFEF4444),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          width: 1.8,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBackground,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Header with App Logo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: _brandGreen.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.asset(
                                'assets/image/AccountApplicationLogo.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "FinTrack",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _primaryText,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Screen Title & Subtitle
                      const Text(
                        "Create Account",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Join FinTrack to manage smart budgets",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Elevated Registration Card
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryText.withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Full Name
                            const Text(
                              "Full Name",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameController,
                              maxLength: 50,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                              decoration: _inputDecoration(
                                hint: "Full Name",
                                prefixIcon: const Icon(
                                  Icons.person_outline_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Phone Number
                            const Text(
                              "Phone Number",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                              decoration: _inputDecoration(
                                hint: "10 digit Number",
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 14, right: 10),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "🇮🇳 +91",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryText,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        height: 18,
                                        width: 1.2,
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ],
                                  ),
                                ),
                                suffixIcon: const Icon(
                                  Icons.phone_outlined,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Email Address
                            const Text(
                              "Email Address",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              maxLength: 100,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                              decoration: _inputDecoration(
                                hint: "Email Address",
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Password
                            const Text(
                              "Password",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passwordController,
                              obscureText: !isPasswordVisible,
                              maxLength: 64,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                              decoration: _inputDecoration(
                                hint: "Password",
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isPasswordVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isPasswordVisible = !isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),

                            // Real-time Password Strength Meter Bar
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: passwordController,
                              builder: (context, val, _) {
                                final pass = val.text;
                                if (pass.isEmpty) return const SizedBox.shrink();
                                final strength = _getPasswordStrength(pass);
                                final color = strength <= 1
                                    ? const Color(0xFFEF4444)
                                    : strength == 2
                                        ? const Color(0xFFF59E0B)
                                        : _brandGreen;
                                final label = strength <= 1
                                    ? "Weak"
                                    : strength == 2
                                        ? "Medium"
                                        : "Strong";

                                return Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: strength / 3.0,
                                          backgroundColor: const Color(0xFFE2E8F0),
                                          color: color,
                                          minHeight: 5,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "Real-time password strength",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: _mutedText,
                                            ),
                                          ),
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
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // Confirm Password
                            const Text(
                              "Confirm Password",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: !isConfirmPasswordVisible,
                              maxLength: 64,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => isLoading ? null : checkDetails(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                              decoration: _inputDecoration(
                                hint: "Confirm Password",
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isConfirmPasswordVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: const Color(0xFF94A3B8),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isConfirmPasswordVisible = !isConfirmPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Terms and Privacy Note
                            const Center(
                              child: Text(
                                "By registering, you agree to FinTrack's Terms of Service and Privacy Policy.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _mutedText,
                                  height: 1.4,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Primary CTA: Register Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : checkDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brandGreen,
                                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  "Register & Get Started",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Footer Sign In Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: _mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          GestureDetector(
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
                            child: const Text(
                              "Log In",
                              style: TextStyle(
                                fontSize: 14,
                                color: _brandGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (isLoading)
              Container(
                height: double.infinity,
                width: double.infinity,
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(color: _brandGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
