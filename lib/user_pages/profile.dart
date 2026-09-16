import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/profile_pages/change_password_page.dart';
import 'package:fin_track/profile_pages/feedback_page.dart';
import 'package:fin_track/profile_pages/personal_information_page.dart';
import 'package:fin_track/profile_pages/report_page.dart';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isActionLoading = false;

  String formatIndianNumber(int number) {
    return NumberFormat('#,##,##0', 'en_IN').format(number);
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
      final phone = user?.email?.split('@').first ?? (await SessionManager.getPhoneNumber() ?? "");
      if (phone.isNotEmpty && phone.length == 10) {
        await FirebaseDatabase.instance.ref("Friends/$phone").remove();
        await FirebaseDatabase.instance.ref("Expenses/$phone").remove();
        await FirebaseDatabase.instance.ref("user_details/$phone").remove();
      }
      await user?.delete();
      Fluttertoast.showToast(msg: "Account deleted successfully");
      if (mounted) {
        context.read<UserProvider>().clearUser();
        context.read<ExpenseProvider>().clearExpenses();
        context.read<FriendProvider>().clearFriends();
      }
      await SessionManager.clearSession();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        Fluttertoast.showToast(msg: "Please re-login before deleting your account.");
      } else {
        Fluttertoast.showToast(msg: e.message ?? "Failed to delete account");
      }
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to delete account: $e");
      if (mounted) {
        setState(() {
          isActionLoading = false;
        });
      }
    }
  }

  final Color themeColor = const Color(0xFF8BC24A);

  Widget menuTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: themeColor.withValues(alpha: 0.15),
          child: Icon(icon, color: themeColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, ExpenseProvider>(
      builder: (context, userProvider, expenseProvider, _) {
        final userName = userProvider.name;
        final email = userProvider.email.isNotEmpty ? userProvider.email : "Not Provided";
        final totalExpense = expenseProvider.totalExpense;
        final recordCount = expenseProvider.records.length;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text(
              "Profile",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: (isActionLoading)
              ? Center(
                  child: CircularProgressIndicator(color: themeColor),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      /// Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              spreadRadius: 1,
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: themeColor,
                              child: const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(email, style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Statistics Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Expense Summary",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      "Total Expenses",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      totalExpense.toINR(compactSymbol: true),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 50,
                                  width: 1,
                                  color: Colors.white54,
                                ),
                                Column(
                                  children: [
                                    const Text(
                                      "Records",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "$recordCount",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),

                  /// Menu Section
                  menuTile(
                    icon: Icons.person_outline,
                    title: "Personal Information",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PersonalInformationPage(),
                        ),
                      );
                    },
                  ),

                  menuTile(
                    icon: Icons.lock_outline,
                    title: "Change Password",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordPage(),
                        ),
                      );
                    },
                  ),

                  menuTile(
                    icon: Icons.bar_chart,
                    title: "Reports",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const Reportpage()),
                      );
                    },
                  ),

                  menuTile(
                    icon: Icons.help_outline,
                    title: "Feedback",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FeedbackPage()),
                      );
                    },
                  ),

                  Container(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Text("Logout Account"),
                                    content: const Text(
                                      "Are you sure you want to Logout this Account?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
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
                                        child: const Text("Logout"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text(
                                "Logout",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: SizedBox(
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    title: const Text("Delete Account"),
                                    content: const Text(
                                      "Are you sure you want to delete this Account?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text("Cancel"),
                                      ),

                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await deleteUser();
                                        },
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text(
                                "Delete",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
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
        );
      },
    );
  }
}
