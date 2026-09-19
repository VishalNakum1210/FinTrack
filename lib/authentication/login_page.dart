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

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null && widget.initialPhoneNumber!.isNotEmpty) {
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
    if (lockoutSeconds > 0) {
      Fluttertoast.showToast(
        msg: "Too many failed attempts. Please wait $lockoutSeconds seconds.",
      );
      return;
    }

    String phoneNumber = username.text.trim();
    String passwordUser = password.text.trim();

    if (phoneNumber.isEmpty || passwordUser.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter your phone number and password");
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
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: "$phoneNumber@fintrack.app",
        password: passwordUser,
      );

      if (userCredential.user != null) {
        failedAttempts = 0;
        final myRef = FirebaseDatabase.instance.ref("user_details/$phoneNumber");
        final event = await myRef.once().timeout(const Duration(seconds: 8));

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
            'DisplayName'
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
          final sessionName = await SessionManager.getUsername();
          if (sessionName != null && sessionName.trim().isNotEmpty && sessionName.trim() != "User") {
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
        if (e.code == 'user-not-found') {
          Fluttertoast.showToast(
            msg: "No account found. If you registered previously, tap Register to link your data.",
          );
        } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          Fluttertoast.showToast(
            msg: "Incorrect password (${5 - failedAttempts} attempts remaining)",
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
            msg: "Email/Password sign-in is disabled in Firebase Console. Please enable it under Authentication > Sign-in method.",
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
          Fluttertoast.showToast(msg: e.message ?? "Authentication failed");
        }
      }
    } catch (e) {
      // Fix auth zombie: sign out if user session could not be established
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      Fluttertoast.showToast(msg: "Connection error: Unable to load user profile. Please retry.");
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
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
                            maxLength: 10,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.black87),
                            decoration: inputDecoration("Phone Number"),
                          ),

                          const SizedBox(height: 20),

                          TextField(
                            controller: password,
                            obscureText: !isPasswordVisible,
                            maxLength: 64,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => (isLoading || lockoutSeconds > 0) ? null : checkUserDetails(),
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
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RegistrationPage(),
                                    ),
                                  );
                                }
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
    ),
  );
}
}
