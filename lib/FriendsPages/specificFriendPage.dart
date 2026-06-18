import 'package:account/FriendsPages/addFriendSpent.dart';
import 'package:account/GetInformation/GetSpecificFriendDetails.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Specificfriendpage extends StatefulWidget {
  final String friend_number;
  const Specificfriendpage({super.key, required this.friend_number});

  @override
  State<Specificfriendpage> createState() => _specificFriendPage();
}

class _specificFriendPage extends State<Specificfriendpage> {
  List<Map<String, dynamic>> friendDetails = [];
  List<Map<String, dynamic>>? ExpensesRecords = [];
  bool isLoading = true;
  String netAmount = "0";
  bool sign = false;
  Future<void> getDetails() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String phone_number = sp.getString("phone_number")!;
    friendDetails = await getSpecificFriendDetails(
      phone_number,
      widget.friend_number,
    );
    if (int.parse(friendDetails[0]["total_take"]) >
        int.parse(friendDetails[0]["total_give"]))
      sign = true;
    if (friendDetails[0].containsKey("Records")) {
      friendDetails[0]["Records"].forEach((key, value) {
        ExpensesRecords!.add(Map<String, dynamic>.from(value));
      });
    }
    print(friendDetails[0]);
    setState(() {
      isLoading = false;
    });
  }

  String formatIndianNumber(int number) {
    return NumberFormat('#,##,##0', 'en_IN').format(number);
  }

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF8BC24A);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text(
          "Amit Patel",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddFriendExpenses(friend_number: widget.friend_number),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Add"),
      ),

      body: (isLoading)
          ? Container(
              child: Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            )
          : Column(
              children: [
                // Profile Card
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8BC24A), Color(0xFF7CB342)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(.35),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white,
                        child: Text(
                          friendDetails[0]["friend_name"][0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        friendDetails[0]["friend_name"],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        friendDetails[0]["friend_number"],
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // Get / Give Cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(.08),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "You Give To Friend",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                NumberFormat.currency(
                                  locale: 'en_IN',
                                  symbol: '₹',
                                  decimalDigits: 0,
                                ).format(
                                  int.tryParse(friendDetails[0]["total_take"]),
                                ),
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(.08),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "You Take",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                NumberFormat.currency(
                                  locale: 'en_IN',
                                  symbol: '₹',
                                  decimalDigits: 0,
                                ).format(
                                  int.tryParse(friendDetails[0]["total_give"]),
                                ),
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Net Balance
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Net Balance",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),

                      SizedBox(height: 6),

                      Text(
                        NumberFormat.currency(
                          locale: 'en_IN',
                          symbol: '₹',
                          decimalDigits: 0,
                        ).format(
                          (int.parse(friendDetails[0]["total_take"]) -
                              int.parse(friendDetails[0]["total_give"])),
                        ),
                        style: TextStyle(
                          color: (sign) ? Colors.green : Colors.red,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Transactions Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Transactions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Transaction List
                Expanded(
                  child: (!friendDetails[0].containsKey("Records")) ?
                  Container(
                    child: Center(
                      child: Text("No Records"),
                    ),
                  )
                  : ListView.builder(
                    padding: EdgeInsets.only(bottom: 25, left: 10, right: 10),
                    itemCount: ExpensesRecords!.length,
                    itemBuilder: (context, index) {
                      return _transactionCard(
                        amount: NumberFormat.currency(
                          locale: 'en_IN',
                          symbol: '₹',
                          decimalDigits: 0,
                        ).format(int.parse(ExpensesRecords![index]["Amount"])),
                        title: ExpensesRecords![index]["Type"],
                        note: ExpensesRecords![index]["Description"],
                        date: ExpensesRecords![index]["Date"],
                        isGive:
                            ExpensesRecords![index]["Type"] ==
                                "Take Money From Friend"
                            ? true
                            : false,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  static Widget _transactionCard({
    required String amount,
    required String title,
    required String note,
    required String date,
    required bool isGive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isGive
                ? Colors.red.withOpacity(.12)
                : Colors.green.withOpacity(.12),
            child: Icon(
              isGive
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: isGive ? Colors.red : Colors.green,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  note,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),

                const SizedBox(height: 4),

                Text(
                  date,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isGive ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}
