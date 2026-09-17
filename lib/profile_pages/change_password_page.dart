import 'package:fin_track/get_information/hash_password.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final Color themeColor = const Color(0xFF8BC24A);

  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool oldPasswordVisible = false;
  bool newPasswordVisible = false;
  bool confirmPasswordVisible = false;

  bool isLoading = false;
  int failedAttempts = 0;
  DateTime? lockoutUntil;

  int _getPasswordStrength(String pass) {
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 6) score++;
    if (pass.length >= 8 && RegExp(r'[a-zA-Z]').hasMatch(pass) && RegExp(r'[0-9]').hasMatch(pass)) score++;
    if (pass.length >= 10 && RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass)) score++;
    return score;
  }

  Future<void> changePassword() async {
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!)) {
      final remaining = lockoutUntil!.difference(DateTime.now()).inSeconds;
      Fluttertoast.showToast(msg: "Too many failed attempts. Locked for ${remaining ~/ 60}m ${remaining % 60}s.");
      return;
    }

    String oldPassword = oldPasswordController.text.trim();
    String newPassword = newPasswordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill all fields");
      return;
    }

    if (newPassword != confirmPassword) {
      Fluttertoast.showToast(msg: "Passwords do not match");
      return;
    }

    if (newPassword == oldPassword) {
      Fluttertoast.showToast(msg: "New password cannot be the same as old password");
      return;
    }

    if (!isPasswordStrong(newPassword)) {
      Fluttertoast.showToast(
        msg: "New password must be at least 6 characters and contain letters & numbers",
      );
      return;
    }

    final phoneNumber = await SessionManager.getPhoneNumber() ?? "";
    final user = FirebaseAuth.instance.currentUser;
    if (phoneNumber.isEmpty || user == null) {
      Fluttertoast.showToast(msg: "User not logged in");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final cred = EmailAuthProvider.credential(
        email: "$phoneNumber@fintrack.app",
        password: oldPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      failedAttempts = 0;
      lockoutUntil = null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password changed successfully!"),
          backgroundColor: Color(0xFF8BC24A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        failedAttempts++;
        if (failedAttempts >= 3) {
          lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
          Fluttertoast.showToast(msg: "3 failed attempts. Locked for 5 minutes.");
        } else {
          Fluttertoast.showToast(msg: "Old password is incorrect (${3 - failedAttempts} attempts remaining)");
        }
      } else if (e.code == 'weak-password') {
        Fluttertoast.showToast(msg: "Password is too weak");
      } else {
        Fluttertoast.showToast(msg: e.message ?? "Failed to change password");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget passwordField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        obscureText: !visible,
        maxLength: 64,
        decoration: InputDecoration(
          counterText: "",
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          floatingLabelStyle: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.lock_outline, color: themeColor),
          suffixIcon: IconButton(
            onPressed: onTap,
            icon: Icon(
              visible ? Icons.visibility : Icons.visibility_off,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: themeColor, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Change Password"),
        centerTitle: true,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: themeColor,
              child: const Icon(
                Icons.lock,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            passwordField(
              label: "Old Password",
              controller: oldPasswordController,
              visible: oldPasswordVisible,
              onTap: () {
                setState(() {
                  oldPasswordVisible = !oldPasswordVisible;
                });
              },
            ),
            passwordField(
              label: "New Password",
              controller: newPasswordController,
              visible: newPasswordVisible,
              onTap: () {
                setState(() {
                  newPasswordVisible = !newPasswordVisible;
                });
              },
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: newPasswordController,
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
                  padding: const EdgeInsets.only(bottom: 14),
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
            passwordField(
              label: "Confirm Password",
              controller: confirmPasswordController,
              visible: confirmPasswordVisible,
              onTap: () {
                setState(() {
                  confirmPasswordVisible = !confirmPasswordVisible;
                });
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : changePassword,
                icon: const Icon(Icons.save),
                label: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Update Password",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
