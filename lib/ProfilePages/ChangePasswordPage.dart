import 'package:FinTrack/GetInformation/HashPassword.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final Color themeColor = const Color(0xFF8BC24A);

  final TextEditingController oldPasswordController =
      TextEditingController();

  final TextEditingController newPasswordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool oldPasswordVisible = false;
  bool newPasswordVisible = false;
  bool confirmPasswordVisible = false;

  bool isLoading = false;

  Future<void> changePassword() async {
    String oldPassword =
        oldPasswordController.text.trim();

    String newPassword =
        newPasswordController.text.trim();

    String confirmPassword =
        confirmPasswordController.text.trim();

    if (oldPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please fill all fields",
      );
      return;
    }

    if (newPassword != confirmPassword) {
      Fluttertoast.showToast(
        msg: "Passwords do not match",
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs =
          await SharedPreferences.getInstance();

      String phoneNumber =
          prefs.getString("phone_number") ?? "";

      DatabaseReference myRef = FirebaseDatabase
          .instance
          .ref("user_details/$phoneNumber");

      DatabaseEvent event = await myRef.once();

      if (!event.snapshot.exists) {
        Fluttertoast.showToast(
          msg: "User not found",
        );
        return;
      }

      Map data = event.snapshot.value as Map;

      String currentPassword =
          data["password"] ?? "";

      if (currentPassword != hashPassword(oldPassword)) {
        Fluttertoast.showToast(
          msg: "Old password is incorrect",
        );
        return;
      }

      await myRef.update({
        "password": hashPassword(newPassword),
      });

      Fluttertoast.showToast(
        msg: "Password changed successfully",
      );

      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString(),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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
        decoration: InputDecoration(
          labelText: label,

          labelStyle: const TextStyle(
            color: Colors.grey,
          ),

          floatingLabelStyle: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.w600,
          ),

          prefixIcon: Icon(
            Icons.lock_outline,
            color: themeColor,
          ),

          suffixIcon: IconButton(
            onPressed: onTap,
            icon: Icon(
              visible
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
          ),

          filled: true,
          fillColor: Colors.white,

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(15),
            borderSide: BorderSide(
              color: themeColor,
              width: 2,
            ),
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
      backgroundColor:
          const Color(0xFFF5F7FA),

      appBar: AppBar(
        title: const Text(
          "Change Password",
        ),
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
              controller:
                  oldPasswordController,
              visible: oldPasswordVisible,
              onTap: () {
                setState(() {
                  oldPasswordVisible =
                      !oldPasswordVisible;
                });
              },
            ),

            passwordField(
              label: "New Password",
              controller:
                  newPasswordController,
              visible: newPasswordVisible,
              onTap: () {
                setState(() {
                  newPasswordVisible =
                      !newPasswordVisible;
                });
              },
            ),

            passwordField(
              label: "Confirm Password",
              controller:
                  confirmPasswordController,
              visible:
                  confirmPasswordVisible,
              onTap: () {
                setState(() {
                  confirmPasswordVisible =
                      !confirmPasswordVisible;
                });
              },
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : changePassword,
                icon: const Icon(
                  Icons.save,
                ),
                label: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Update Password",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      themeColor,
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
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