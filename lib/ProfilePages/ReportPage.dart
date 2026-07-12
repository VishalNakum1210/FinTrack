import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Reportpage extends StatefulWidget {
  @override
  State<Reportpage> createState() => _reportPage();
}

class _reportPage extends State<Reportpage> {
  bool isLoading = false;
  double totalIncome = 0;
  double totalExpense = 0;
  double currentBalance = 0;
  double cashBalance = 0;
  double onlineBalance = 0;
  String topCategory = "";
  double friendGiven = 0;
  double friendTaken = 0;
  double highestIncome = 0;

  int transactionCount = 0;

  Map<String, double> categoryTotals = {};

  List<Map> recentTransactions = [];

  Future<void> loadReportData() async {
    setState(() {
      isLoading = true;
    });
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();

      String phone = sp.getString("phone_number") ?? "";

      totalIncome = 0;
      totalExpense = 0;

      cashBalance = 0;
      onlineBalance = 0;

      friendGiven = 0;
      friendTaken = 0;

      transactionCount = 0;

      categoryTotals.clear();
      recentTransactions.clear();

      // Change Expenses to Records if needed
      DatabaseReference expenseRef = FirebaseDatabase.instance.ref(
        "Expenses/$phone",
      );

      DataSnapshot expenseSnap = await expenseRef.get();

      if (expenseSnap.exists) {
        Map<dynamic, dynamic> data = expenseSnap.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          try {
            Map<String, dynamic> record = Map<String, dynamic>.from(value);

            double amount = double.parse(record["Amount"]);

            String paymentMode = record["Payment_Mode"]?.toString() ?? "";

            String category = record["Category"]?.toString() ?? "Other";

            transactionCount++;

            // Save for recent activity
            recentTransactions.add({
              "amount": amount,
              "category": category,
              "payment": paymentMode,
              "timestamp": record["timestamp"] ?? 0,
            });

            // Income
            if (paymentMode.contains("Add")) {
              totalIncome += amount;

              if (amount > highestIncome) {
                highestIncome = amount;
              }
            }

            // Expense
            if (paymentMode.contains("Spent")) {
              totalExpense += amount;
            }

            // Cash
            if (paymentMode == "Add CASH") {
              cashBalance += amount;
            }

            if (paymentMode == "Spent Cash") {
              cashBalance -= amount;
            }

            // Online
            if (paymentMode == "Add Online") {
              onlineBalance += amount;
            }

            if (paymentMode == "Spent Online") {
              onlineBalance -= amount;
            }

            // Categories
            if (paymentMode.contains("Spent")) {
              categoryTotals[category] =
                  (categoryTotals[category] ?? 0) + amount;
            }
            if (paymentMode.contains("Add")) {
              totalIncome += amount;

              if (amount > highestIncome) {
                highestIncome = amount;
              }
            }
          } catch (e) {
            print(e);
          }
        });
      }

      // Current Balance
      currentBalance = cashBalance + onlineBalance;

      // Top Category
      if (categoryTotals.isNotEmpty) {
        topCategory = categoryTotals.entries
            .reduce((a, b) => (a.value > b.value) ? a : b)
            .key;
      }

      // Recent Transactions
      recentTransactions.sort(
        (a, b) => (b["timestamp"] ?? 0).compareTo(a["timestamp"] ?? 0),
      );

      // Friends
      DatabaseReference friendRef = FirebaseDatabase.instance.ref(
        "Friends/$phone",
      );

      DataSnapshot friendSnap = await friendRef.get();

      if (friendSnap.exists) {
        Map<dynamic, dynamic> friends =
            friendSnap.value as Map<dynamic, dynamic>;

        friends.forEach((key, value) {
          try {
            Map<String, dynamic> friend = Map<String, dynamic>.from(value);

            friendGiven += double.tryParse(friend["total_get"].toString()) ?? 0;

            friendTaken +=
                double.tryParse(friend["total_give"].toString()) ?? 0;
          } catch (e) {
            print(e);
          }
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Report Error: $e");

      setState(() {
        isLoading = false;
      });
    }
  }

  double get healthScore {
    if (totalIncome <= 0) return 0;

    return ((totalIncome - totalExpense) / totalIncome).clamp(0.0, 1.0);
  }

  String get healthText {
    if (healthScore >= .8) {
      return "Excellent";
    }

    if (healthScore >= .6) {
      return "Good";
    }

    if (healthScore >= .4) {
      return "Average";
    }

    return "Needs Improvement";
  }

  double get highestCategoryAmount {
    if (categoryTotals.isEmpty) return 0;

    return categoryTotals.values.reduce((a, b) => a > b ? a : b);
  }

  String money(num value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  void initState() {
    super.initState();
    loadReportData();
  }

  final Color themeColor = const Color(0xFF8BC24A);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FBF2),
        body: Center(child: CircularProgressIndicator(color: themeColor)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FBF2),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Reports",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: (isLoading)
          ? Container(
              child: Center(
                child: CircularProgressIndicator(color: themeColor),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Balance Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        colors: [themeColor, themeColor.withOpacity(.75)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Balance",
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "${money(currentBalance)}",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.trending_up, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              "${((healthScore) * 100).toStringAsFixed(0)}% healthy",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: healthScore,
                                color: themeColor,
                                strokeWidth: 8,
                              ),
                              Text(
                                "${(healthScore * 100).toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Financial Health",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(healthText),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const SizedBox(height: 20),

                  // Quick Insights
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Quick Insights",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _insightCard(
                        icon: Icons.shopping_bag,
                        title: "Biggest Expense",
                        value: topCategory,
                      ),
                      _insightCard(
                        icon: Icons.monetization_on,
                        title: "Highest Income",
                        value: "${money(highestIncome)}",
                      ),
                      _insightCard(
                        icon: Icons.receipt_long,
                        title: "Transactions",
                        value: transactionCount.toString(),
                      ),
                      _insightCard(
                        icon: Icons.calendar_month,
                        title: "Active Days",
                        value: recentTransactions.length.toString(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Top Categories
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Top Categories",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ...categoryTotals.entries.take(3).map((e) {
                    return _categoryTile(
                      themeColor: themeColor,
                      icon: Icons.category,
                      title: e.key,
                      amount: "${money(e.value)}",
                      value: e.value / totalExpense,
                    );
                  }),

                  const SizedBox(height: 20),

                  // Friend Summary
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, color: themeColor),
                            const SizedBox(width: 10),
                            const Text(
                              "Friend Summary",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Money You Get"),
                            Text(
                              "${money(friendGiven)}",
                              style: TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Money You Want To Give"),
                            Text(
                              "${money(friendTaken)}",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 25),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Net Balance",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              money(friendGiven - friendTaken),
                              style: TextStyle(
                                color: (friendGiven < friendTaken)
                                    ? Colors.red
                                    : themeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Recent Activity
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Recent Activity",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        ...recentTransactions.take(5).map((record) {
                          bool isExpense = record["payment"]
                              .toString()
                              .contains("Spent");

                          return _activityTile(
                            themeColor,
                            isExpense
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            record["category"].toString(),
                            "${isExpense ? "-" : "+"}${money(record["amount"])}",
                            isExpense ? Colors.red : themeColor,
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _insightCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon(icon, color: themeColor, size: 30),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _categoryTile({
    required Color themeColor,
    required IconData icon,
    required String title,
    required String amount,
    required double value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: themeColor.withOpacity(.15),
                child: Icon(icon, color: themeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: themeColor.withOpacity(.15),
            valueColor: AlwaysStoppedAnimation(themeColor),
          ),
        ],
      ),
    );
  }

  Widget _activityTile(
    Color themeColor,
    IconData icon,
    String title,
    String amount,
    Color amountColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: themeColor.withValues(alpha: .15),
            child: Icon(icon, color: themeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            amount,
            style: TextStyle(color: amountColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
