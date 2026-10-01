import 'dart:async';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/authentication/registration_page.dart';
import 'package:fin_track/nav_bar.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  final String? initialPhoneNumber;
  const LoginPage({super.key, this.initialPhoneNumber});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool isLoading = false;
  bool isPasswordVisible = false;

  int failedAttempts = 0;
  int lockoutSeconds = 0;
  Timer? lockoutTimer;

  static const Color _brandGreen = Color(0xFF8BC24A);
  static const Color _canvasBackground = Color(0xFFF8FAFC);
  static const Color _primaryText = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null &&
        widget.initialPhoneNumber!.isNotEmpty) {
      username.text = widget.initialPhoneNumber!;
    }
  }

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
    if (isLoading) return;
    if (lockoutSeconds > 0) {
      Fluttertoast.showToast(
        msg: "Too many failed attempts. Please wait $lockoutSeconds seconds.",
      );
      return;
    }

    String phoneNumber = username.text.trim();
    String passwordUser = password.text;

    if (phoneNumber.isEmpty || passwordUser.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter your phone number and password",
      );
      return;
    }
    if (phoneNumber.length != 10 || int.tryParse(phoneNumber) == null) {
      Fluttertoast.showToast(msg: "Please enter a valid 10-digit phone number");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: "$phoneNumber@fintrack.app",
            password: passwordUser,
          );

      if (userCredential.user != null) {
        failedAttempts = 0;
        final myRef = FirebaseDatabase.instance.ref(
          "user_details/$phoneNumber",
        );
        var event = await myRef.once().timeout(const Duration(seconds: 8));

        if (!event.snapshot.exists ||
            (event.snapshot.value is Map &&
                (event.snapshot.value as Map)['deletion_pending'] == true &&
                (event.snapshot.value as Map)['owner_uid'] !=
                    userCredential.user!.uid)) {
          // Resume provisioning using the SAME Auth UID after an interrupted
          // registration. Rules prohibit adopting orphaned financial roots.
          await myRef.set({
            'owner_uid': userCredential.user!.uid,
            'phone_number': phoneNumber,
            'name': userCredential.user?.displayName?.trim().isNotEmpty == true
                ? userCredential.user!.displayName!.trim()
                : 'User',
            'email': '',
            'created_at': ServerValue.timestamp,
          });
          event = await myRef.once().timeout(const Duration(seconds: 8));
        } else if (event.snapshot.value is Map &&
            (event.snapshot.value as Map)['owner_uid'] == null) {
          try {
            await myRef.update({'owner_uid': userCredential.user!.uid});
          } catch (_) {}
        }

        String name = "User";
        String email = "";
        if (event.snapshot.value != null && event.snapshot.value is Map) {
          final values = Map<String, dynamic>.from(event.snapshot.value as Map);
          for (final key in [
            'name',
            'Name',
            'username',
            'userName',
            'fullName',
            'FullName',
            'displayName',
            'DisplayName',
          ]) {
            final val = values[key]?.toString().trim();
            if (val != null && val.isNotEmpty && val != 'User') {
              name = val;
              break;
            }
          }
          email = (values["email"] ?? values["Email"] ?? "").toString().trim();
        }

        // Fallback to FirebaseAuth displayName
        if (name == "User" || name.isEmpty) {
          final authName = userCredential.user?.displayName?.trim();
          if (authName != null && authName.isNotEmpty && authName != "User") {
            name = authName;
          }
        }

        // Fallback to SessionManager cached username
        if (name == "User" || name.isEmpty) {
          final sessionName =
              await SessionManager.getPhoneNumber() == phoneNumber
              ? await SessionManager.getUsername()
              : null;
          if (sessionName != null &&
              sessionName.trim().isNotEmpty &&
              sessionName.trim() != "User") {
            name = sessionName.trim();
          }
        }

        // Sync displayName and RTDB if valid name resolved
        if (name != "User" && name.isNotEmpty) {
          try {
            if (userCredential.user?.displayName != name) {
              await userCredential.user?.updateDisplayName(name);
            }
          } catch (_) {}
          try {
            if (event.snapshot.value == null ||
                event.snapshot.value is! Map ||
                (event.snapshot.value as Map)["name"] == null) {
              await myRef.update({"name": name, "phone_number": phoneNumber});
            }
          } catch (_) {}
        }

        try {
          await SessionManager.saveSession(
            phoneNumber: phoneNumber,
            username: name,
            email: email,
          );
        } catch (_) {
          // Local profile caching cannot invalidate remote provisioning.
        }

        if (mounted) {
          context.read<UserProvider>().loadUserSession();
          context.read<ExpenseProvider>().fetchExpenses(phoneNumber);
          context.read<FriendProvider>().fetchFriends(phoneNumber);
        }

        Fluttertoast.showToast(msg: "Login successful");
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavPageSelector()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      failedAttempts++;
      if (failedAttempts >= 5) {
        startLockoutTimer();
        Fluttertoast.showToast(
          msg: "Too many failed attempts. Locked for 30 seconds.",
        );
      } else {
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          Fluttertoast.showToast(
            msg: "Unable to sign in. Check your credentials and try again.",
          );
        } else if (e.code == 'user-disabled') {
          Fluttertoast.showToast(
            msg: "This account has been disabled. Please contact support.",
          );
        } else if (e.code == 'too-many-requests') {
          startLockoutTimer();
          Fluttertoast.showToast(
            msg: "Too many attempts. Account temporarily locked by server.",
          );
        } else if (e.code == 'network-request-failed') {
          Fluttertoast.showToast(
            msg: "Network error. Please check your internet connection.",
          );
        } else if (e.code == 'operation-not-allowed') {
          Fluttertoast.showToast(
            msg:
                "Email/Password sign-in is disabled in Firebase Console. Please enable it under Authentication > Sign-in method.",
          );
        } else if (e.code == 'invalid-email') {
          Fluttertoast.showToast(
            msg: "Please enter a valid 10-digit phone number.",
          );
        } else if (e.code == 'channel-error') {
          Fluttertoast.showToast(
            msg: "Please enter your phone number and password.",
          );
        } else {
          Fluttertoast.showToast(msg: "Unable to sign in. Please try again.");
        }
      }
    } catch (e) {
      // Fix auth zombie: sign out if user session could not be established
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      Fluttertoast.showToast(
        msg: "Connection error: Unable to load user profile. Please retry.",
      );
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
        borderSide: const BorderSide(width: 1.2, color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.8, color: _brandGreen),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.2, color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.8, color: Color(0xFFEF4444)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBackground,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // FinTrack Brand Header with App Logo
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
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

                      const SizedBox(height: 22),

                      // Welcome Back Title & Subtitle
                      const Text(
                        "Welcome Back!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _primaryText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Log in to track your personal finances",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Elevated Authentication Card
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
                            // Phone Number Label & Input
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
                              controller: username,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                              decoration: _inputDecoration(
                                hint: "Enter 10 digit number",
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 14,
                                    right: 10,
                                  ),
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

                            const SizedBox(height: 18),

                            // Password Label & Input
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
                              controller: password,
                              obscureText: !isPasswordVisible,
                              maxLength: 128,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) =>
                                  (isLoading || lockoutSeconds > 0)
                                  ? null
                                  : checkUserDetails(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primaryText,
                              ),
                              decoration: _inputDecoration(
                                hint: "Password",
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

                            const SizedBox(height: 12),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  Fluttertoast.showToast(
                                    msg:
                                        "Please contact support or admin to reset your credentials.",
                                  );
                                },
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _mutedText,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Primary CTA: Log In Button
                            SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (isLoading || lockoutSeconds > 0)
                                    ? null
                                    : checkUserDetails,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _brandGreen,
                                  disabledBackgroundColor: const Color(
                                    0xFFCBD5E1,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  lockoutSeconds > 0
                                      ? "Locked (${lockoutSeconds}s)"
                                      : "Log In",
                                  style: const TextStyle(
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

                      const SizedBox(height: 24),

                      // Sign Up Footer Link
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 6,
                        children: [
                          const Text(
                            "Don't have an account? ",
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RegistrationPage(),
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              "Sign Up",
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
                width: double.infinity,
                height: double.infinity,
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
