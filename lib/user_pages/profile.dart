import 'dart:async';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/profile_pages/change_password_page.dart';
import 'package:fin_track/profile_pages/data_backup_page.dart';
import 'package:fin_track/profile_pages/edit_information_page.dart';
import 'package:fin_track/profile_pages/feedback_page.dart';
import 'package:fin_track/profile_pages/personal_information_page.dart';
import 'package:fin_track/profile_pages/report_page.dart';
import 'package:fin_track/profile_pages/terms_and_privacy_page.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF689F38);
  static const Color _canvasBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderGrey = Color(0xFFE2E8F0);

  bool isActionLoading = false;
  bool _deleteCooldown = false;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> logout() async {
    if (isActionLoading) return;
    if (mounted) {
      setState(() {
        isActionLoading = true;
      });
    }
    if (mounted) {
      context.read<UserProvider>().clearUser();
      context.read<ExpenseProvider>().clearExpenses();
      context.read<FriendProvider>().clearFriends();
    }
    await FirebaseAuth.instance.signOut();
    await SessionManager.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> deleteUser() async {
    if (isActionLoading) return;
    if (mounted) {
      setState(() {
        isActionLoading = true;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Fluttertoast.showToast(msg: "No active user found. Please re-login.");
        if (mounted) setState(() => isActionLoading = false);
        return;
      }

      final phone = await SessionManager.getPhoneNumber();
      if (phone == null) throw StateError('No active session');
      final password = await _promptPasswordForReauth();
      if (password == null || password.isEmpty) {
        if (mounted) setState(() => isActionLoading = false);
        return;
      }
      // Confirm credentials before deleting any data, including when an old
      // Auth session would otherwise reject account deletion.
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
      await FirebaseDatabase.instance.ref().update({
        'Friends/$phone': null,
        'Expenses/$phone': null,
        'Trips/$phone': null,
        'userUpdates/$phone': null,
        // Retain a scrubbed ownership tombstone until Auth deletion completes.
        // Cleanup can be retried by the same UID; a future UID can replace it
        // only after all financial roots have been removed (enforced by rules).
        'WriteOperations/$phone': null,
        'user_details/$phone': {
          'owner_uid': user.uid,
          'phone_number': phone,
          'name': 'Deleted account',
          'email': '',
          'deletion_pending': true,
        },
      });
      await user.delete();

      Fluttertoast.showToast(msg: "Account deleted successfully");
      if (mounted) {
        context.read<UserProvider>().clearUser();
        context.read<ExpenseProvider>().clearExpenses();
        context.read<FriendProvider>().clearFriends();
      }
      try {
        await SessionManager.clearSession();
      } catch (_) {
        // Remote deletion succeeded. Local cleanup must not claim failure.
      }
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Unable to delete account. Please sign in again and retry.",
      );
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  Future<String?> _promptPasswordForReauth() async {
    final passCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "For security, please enter your password to confirm account deletion:",
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, passCtrl.text),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
    passCtrl.dispose();
    return result;
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out of FinTrack?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              logout();
            },
            child: const Text("Log Out"),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    int countdown = 5;
    Timer? dialogTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          dialogTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!context.mounted) {
              timer.cancel();
              return;
            }
            if (countdown > 1) {
              setDialogState(() {
                countdown--;
              });
            } else {
              timer.cancel();
              setDialogState(() {
                countdown = 0;
              });
            }
          });

          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) {
              dialogTimer?.cancel();
            },
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("Delete Account"),
              content: const Text(
                "Are you sure you want to permanently delete your account? All expense and friends ledger data will be deleted.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogTimer?.cancel();
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: countdown == 0
                      ? () async {
                          dialogTimer?.cancel();
                          setState(() => _deleteCooldown = true);
                          _cooldownTimer?.cancel();
                          _cooldownTimer = Timer(
                            const Duration(seconds: 5),
                            () {
                              if (mounted) {
                                setState(() => _deleteCooldown = false);
                              }
                            },
                          );
                          Navigator.pop(dialogCtx);
                          await deleteUser();
                        }
                      : null,
                  child: Text(
                    countdown > 0
                        ? "Delete (${countdown}s)"
                        : "Delete Permanently",
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      dialogTimer?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, ExpenseProvider>(
      builder: (context, userProvider, expenseProvider, _) {
        final userName =
            userProvider.name.isNotEmpty && userProvider.name != "User"
            ? userProvider.name
            : "User"; // FIX M2: removed hardcoded "Vishal" personal name
        final phone = userProvider.phoneNumber;
        final email = userProvider.email.isNotEmpty
            ? userProvider.email
            : "user@fintrack.app";
        final userSubtitle = phone.isNotEmpty
            ? (phone.startsWith("+") ? phone : "+91 $phone")
            : email;

        final totalExpense = expenseProvider.totalExpense;
        final recordCount = expenseProvider.records.length;

        if (isActionLoading) {
          return const Scaffold(
            backgroundColor: _canvasBg,
            body: Center(
              child: CircularProgressIndicator(color: _primaryGreen),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _canvasBg,
          body: SingleChildScrollView(
            child: Column(
              children: [
                // 1. TOP CURVED GREEN HEADER
                _buildGreenHeader(),

                // 2. OVERLAPPING USER PROFILE CARD (60px Avatar + Edit Profile Pill)
                Transform.translate(
                  offset: const Offset(0, -50),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildUserProfileHeaderCard(
                          userName: userName,
                          subtitle: userSubtitle,
                        ),

                        const SizedBox(height: 16),

                        // 3. BALANCED SUMMARY CARDS (Card 1: Total Spent, Card 2: Records)
                        _buildBalancedSummaryCards(
                          totalExpense: totalExpense,
                          recordCount: recordCount,
                        ),

                        const SizedBox(height: 16),

                        // 4. ACTION NAVIGATION TILES (14px Corner Radius)
                        _buildNavigationTiles(),

                        const SizedBox(height: 14),

                        // 5. DELETE ACCOUNT DANGER BUTTON
                        _buildDeleteAccountTile(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. TOP GREEN HEADER AREA
  // ===========================================================================
  Widget _buildGreenHeader() {
    return Container(
      width: double.infinity,
      height: 155,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryGreen, _darkGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(top: 14, left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Profile & Settings",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. USER PROFILE HEADER CARD (Overlapping, 60px circular avatar)
  // ===========================================================================
  Widget _buildUserProfileHeaderCard({
    required String userName,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderGrey, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 60px Circular Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8F5E9),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _primaryGreen.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _darkGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // User Name
          Text(
            userName,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),

          // Subtitle / Phone Number
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // "Edit Profile" Pill Button
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditInformationPage()),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 6.5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              ),
              child: const Text(
                "Edit Profile",
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _darkGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. BALANCED SUMMARY CARDS (Card 1: Total Spent, Card 2: Records)
  // ===========================================================================
  Widget _buildBalancedSummaryCards({
    required double totalExpense,
    required int recordCount,
  }) {
    return Row(
      children: [
        // Card 1: Total Spent
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderGrey, width: 1),
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
                const Text(
                  "Total Spent:",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    totalExpense.toINR(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Card 2: Records
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderGrey, width: 1),
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
                const Text(
                  "Records:",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "$recordCount",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. ACTION NAVIGATION TILES (14px Corner Radius)
  // ===========================================================================
  Widget _buildNavigationTiles() {
    return Column(
      children: [
        _buildNavTile(
          icon: Icons.person_rounded,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
          title: "Personal Information",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PersonalInformationPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          icon: Icons.lock_rounded,
          iconBg: const Color(0xFFFFF8E1),
          iconColor: const Color(0xFFF57F17),
          title: "Security & Password",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          icon: Icons.bar_chart_rounded,
          iconBg: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF1976D2),
          title: "Financial Reports",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Reportpage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          icon: Icons.cloud_download_rounded,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
          title: "Cloud Backup & Export",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DataBackupPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          icon: Icons.chat_bubble_rounded,
          iconBg: const Color(0xFFF3E5F5),
          iconColor: const Color(0xFF7B1FA2),
          title: "Feedback & Support",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          icon: Icons.policy_rounded,
          iconBg: const Color(0xFFE0F2FE),
          iconColor: const Color(0xFF0284C7),
          title: "Terms & Privacy Policy",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsAndPrivacyPage()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildNavTile(
          icon: Icons.logout_rounded,
          iconBg: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFD32F2F),
          title: "Log Out",
          titleColor: const Color(0xFFD32F2F),
          onTap: _showLogoutDialog,
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderGrey, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: titleColor ?? _textDark,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: titleColor ?? const Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. DELETE ACCOUNT DANGER TILE
  // ===========================================================================
  Widget _buildDeleteAccountTile() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _deleteCooldown ? null : _showDeleteAccountDialog,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE11D48),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _deleteCooldown ? "Please wait..." : "Delete Account",
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFE11D48),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
