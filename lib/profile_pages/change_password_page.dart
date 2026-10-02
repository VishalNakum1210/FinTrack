import 'dart:async';
import 'package:fin_track/get_information/password_policy.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF2E7D32);
  static const Color _canvasBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderGrey = Color(0xFFE2E8F0);

  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool oldPasswordVisible = false;
  bool newPasswordVisible = false;
  bool confirmPasswordVisible = false;

  bool isLoading = false;
  int failedAttempts = 0;
  DateTime? lockoutUntil;
  Timer? _lockoutTimer;

  static const _prefLockoutKey = 'change_pw_lockout_epoch';
  static const _prefAttemptsKey = 'change_pw_attempts';

  @override
  void initState() {
    super.initState();
    newPasswordController.addListener(() {
      if (mounted) setState(() {});
    });
    confirmPasswordController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadLockoutState();
  }

  Future<void> _loadLockoutState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockoutEpoch = prefs.getInt(_prefLockoutKey);
      final storedAttempts = prefs.getInt(_prefAttemptsKey) ?? 0;
      if (lockoutEpoch != null) {
        final until = DateTime.fromMillisecondsSinceEpoch(lockoutEpoch);
        if (DateTime.now().isBefore(until)) {
          if (mounted) {
            setState(() {
              failedAttempts = storedAttempts;
              lockoutUntil = until;
            });
            _startLockoutTimer();
          }
        } else {
          await prefs.remove(_prefLockoutKey);
          await prefs.remove(_prefAttemptsKey);
        }
      } else {
        if (mounted && storedAttempts > 0) {
          setState(() {
            failedAttempts = storedAttempts;
          });
        }
      }
    } catch (_) {}
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (lockoutUntil != null && DateTime.now().isAfter(lockoutUntil!)) {
        timer.cancel();
        SharedPreferences.getInstance().then((p) {
          p.remove(_prefLockoutKey);
          p.remove(_prefAttemptsKey);
        });
        if (mounted) {
          setState(() {
            lockoutUntil = null;
            failedAttempts = 0;
          });
        }
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  int _getPasswordStrength(String pass) {
    if (pass.isEmpty) return 0;
    int score = 0;
    if (pass.length >= 12) score++;
    if (pass.length >= 12 &&
        RegExp(r'[a-zA-Z]').hasMatch(pass) &&
        RegExp(r'[0-9]').hasMatch(pass)) {
      score++;
    }
    if (pass.length >= 16 &&
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass)) {
      score++;
    }
    return score;
  }

  Future<void> changePassword() async {
    if (isLoading) return;
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!)) {
      final remaining = lockoutUntil!.difference(DateTime.now()).inSeconds;
      Fluttertoast.showToast(
        msg:
            "Too many failed attempts. Locked for ${remaining ~/ 60}m ${remaining % 60}s.",
      );
      return;
    }

    String oldPassword = oldPasswordController.text;
    String newPassword = newPasswordController.text;
    String confirmPassword = confirmPasswordController.text;

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill all fields");
      return;
    }

    if (newPassword != confirmPassword) {
      Fluttertoast.showToast(msg: "Passwords do not match");
      return;
    }

    if (newPassword == oldPassword) {
      Fluttertoast.showToast(
        msg: "New password cannot be the same as old password",
      );
      return;
    }

    if (!isPasswordStrong(newPassword)) {
      Fluttertoast.showToast(
        msg: "Use 12–128 characters with letters and numbers or symbols",
      );
      return;
    }

    final phoneNumber = await SessionManager.getPhoneNumber() ?? "";
    final user = FirebaseAuth.instance.currentUser;
    if (phoneNumber.isEmpty || user == null) {
      Fluttertoast.showToast(msg: "Session expired. Please log in again.");
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
      _lockoutTimer?.cancel();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefLockoutKey);
        await prefs.remove(_prefAttemptsKey);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password changed successfully!"),
          backgroundColor: _primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        failedAttempts++;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_prefAttemptsKey, failedAttempts);
          if (failedAttempts >= 3) {
            lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
            await prefs.setInt(
              _prefLockoutKey,
              lockoutUntil!.millisecondsSinceEpoch,
            );
            _startLockoutTimer();
            Fluttertoast.showToast(
              msg: "3 failed attempts. Locked for 5 minutes.",
            );
          } else {
            Fluttertoast.showToast(
              msg:
                  "Old password is incorrect (${3 - failedAttempts} attempts remaining)",
            );
          }
        } catch (_) {}
      } else if (e.code == 'weak-password') {
        Fluttertoast.showToast(
          msg: "New password is too weak. Please use a stronger password.",
        );
      } else if (e.code == 'too-many-requests') {
        Fluttertoast.showToast(
          msg: "Too many attempts. Please wait a moment before trying again.",
        );
      } else if (e.code == 'network-request-failed') {
        Fluttertoast.showToast(
          msg: "Network error. Please check your internet connection.",
        );
      } else if (e.code == 'requires-recent-login') {
        Fluttertoast.showToast(
          msg: "Security check: Please log in again to change your password.",
        );
      } else {
        Fluttertoast.showToast(
          msg: "Unable to change password. Please try again.",
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg:
            "Unable to change password. Please check your connection and retry.",
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
    required String hintText,
    required IconData prefixIcon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF94A3B8),
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(prefixIcon, color: _primaryGreen, size: 20),
      suffixIcon: IconButton(
        icon: Icon(
          isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          color: const Color(0xFF94A3B8),
          size: 20,
        ),
        onPressed: onToggleVisibility,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryGreen, width: 1.8),
      ),
    );
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked =
        lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);
    final remainingSeconds = isLocked
        ? lockoutUntil!.difference(DateTime.now()).inSeconds
        : 0;

    final newPassText = newPasswordController.text;
    final strength = _getPasswordStrength(newPassText);
    final strengthColor = strength <= 1
        ? const Color(0xFFE53935)
        : strength == 2
        ? const Color(0xFFFB8C00)
        : const Color(0xFF43A047);
    final strengthLabel = strength <= 1
        ? "Weak"
        : strength == 2
        ? "Medium"
        : "Strong";

    final confirmText = confirmPasswordController.text;
    final bool passwordsMatch =
        newPassText.isNotEmpty &&
        confirmText.isNotEmpty &&
        newPassText == confirmText;

    return Scaffold(
      backgroundColor: _canvasBg,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Security & Password",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Lockout Banner (if active)
              if (isLocked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        color: Color(0xFFDC2626),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Account locked due to multiple failed attempts. Retry in ${remainingSeconds ~/ 60}m ${remainingSeconds % 60}s.",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Hero Security Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borderGrey),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8F5E9),
                        border: Border.all(
                          color: const Color(0xFFC8E6C9),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_outlined,
                          color: _darkGreen,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Protect Your Account",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Use 12–128 characters with letters and numbers or symbols.",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Section Title
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  "PASSWORD DETAILS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // Form Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderGrey),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Password
                    const Text(
                      "Current Password",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: oldPasswordController,
                      obscureText: !oldPasswordVisible,
                      maxLength: 128,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(
                        hintText: "Enter current password",
                        prefixIcon: Icons.lock_outline_rounded,
                        isVisible: oldPasswordVisible,
                        onToggleVisibility: () {
                          setState(
                            () => oldPasswordVisible = !oldPasswordVisible,
                          );
                        },
                      ).copyWith(counterText: ""),
                    ),

                    const SizedBox(height: 18),

                    // New Password
                    const Text(
                      "New Password",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPasswordController,
                      obscureText: !newPasswordVisible,
                      maxLength: 128,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(
                        hintText: "Enter new password",
                        prefixIcon: Icons.vpn_key_outlined,
                        isVisible: newPasswordVisible,
                        onToggleVisibility: () {
                          setState(
                            () => newPasswordVisible = !newPasswordVisible,
                          );
                        },
                      ).copyWith(counterText: ""),
                    ),

                    // Dynamic Strength Meter
                    if (newPassText.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: strength / 3.0,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  strengthColor,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: strengthColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              strengthLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: strengthColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Confirm Password
                    const Text(
                      "Confirm New Password",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: !confirmPasswordVisible,
                      maxLength: 128,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          (isLoading || isLocked) ? null : changePassword(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(
                        hintText: "Re-enter new password",
                        prefixIcon: Icons.check_circle_outline_rounded,
                        isVisible: confirmPasswordVisible,
                        onToggleVisibility: () {
                          setState(
                            () => confirmPasswordVisible =
                                !confirmPasswordVisible,
                          );
                        },
                      ).copyWith(counterText: ""),
                    ),

                    // Password match indicator
                    if (confirmText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            passwordsMatch
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 14,
                            color: passwordsMatch
                                ? _darkGreen
                                : const Color(0xFFE53935),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              passwordsMatch
                                  ? "Passwords match"
                                  : "Passwords do not match",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: passwordsMatch
                                    ? _darkGreen
                                    : const Color(0xFFE53935),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Primary CTA: Update Password Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (isLoading || isLocked) ? null : changePassword,
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.lock_reset_rounded, size: 20),
                  label: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isLocked
                              ? "Locked (${remainingSeconds}s)"
                              : "Update Password",
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
