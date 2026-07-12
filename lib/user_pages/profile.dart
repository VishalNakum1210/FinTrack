import 'package:FinTrack/GetInformation/GetInformationForProfile.dart';
import 'package:FinTrack/ProfilePages/ChangePasswordPage.dart';
import 'package:FinTrack/ProfilePages/FeedbackPage.dart';
import 'package:FinTrack/ProfilePages/PersonalInformationPage.dart';
import 'package:FinTrack/ProfilePages/ReportPage.dart';
import 'package:FinTrack/authantication/login_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userName = "User";
  String email = "User@gmail.com";
  List<String> ExpensesRecord = ["0", "0"];
  bool isLoading = false;

  void getDetails() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences sp = await SharedPreferences.getInstance();
    String phone_number = sp.getString("phone_number")!;
    userName = sp.getString("username")!;
    email = sp.getString("email")!;
    ExpensesRecord = await getProfieInformation(phone_number);
    setState(() {
      isLoading = false;
    });
  }

  String formatIndianNumber(int number) {
    return NumberFormat('#,##,##0', 'en_IN').format(number);
  }

  void Logout() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences sp = await SharedPreferences.getInstance();
    await sp.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  Future<void> DeleteUser() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences sp = await SharedPreferences.getInstance();
    String phone = sp.getString("phone_number")!;
    DatabaseReference myref = FirebaseDatabase.instance.ref("Friends/$phone");
    await myref.remove();

    myref = FirebaseDatabase.instance.ref("Expenses/$phone");
    await myref.remove();

    myref = FirebaseDatabase.instance.ref("user_details/$phone");
    await myref.remove();

    Fluttertoast.showToast(msg: "Account is Deleted successfully");
    sp.clear();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    getDetails();
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

      body: (isLoading)
          ? Container(
              child: Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
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
                                  NumberFormat.currency(
                                    locale: 'en_IN',
                                    symbol: '₹',
                                    decimalDigits: 0,
                                  ).format(int.tryParse(ExpensesRecord[0])),
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
                                  NumberFormat.currency(
                                    locale: 'en_IN',
                                    symbol: '',
                                    decimalDigits: 0,
                                  ).format(int.tryParse(ExpensesRecord[1])),
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
                          builder: (context) => PersonalInformationPage(),
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
                          builder: (context) => ChangePasswordPage(),
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
                        MaterialPageRoute(builder: (context) => Reportpage()),
                      );
                    },
                  ),

                  menuTile(
                    icon: Icons.help_outline,
                    title: "Feedback",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FeedbackPage()),
                      );
                    },
                  ),

                  Container(
                    padding: EdgeInsets.only(left: 10, right: 10),
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
                                          Logout();
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

                        SizedBox(width: 10),

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
                                          await DeleteUser();
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
  }
}
