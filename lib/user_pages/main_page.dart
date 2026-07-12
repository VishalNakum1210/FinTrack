import 'package:FinTrack/GetInformation/GetAllInformation.dart';
import 'package:FinTrack/GetInformation/GetAllRecords.dart';
import 'package:FinTrack/user_pages/add_spent.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserMainPage extends StatefulWidget {
  const UserMainPage({super.key});

  @override
  State<UserMainPage> createState() => _UserMainPageState();
}

class _UserMainPageState extends State<UserMainPage> {
  final Color themeColor = const Color(0xFF8BC24A);

  bool isLoading = true;

  String? name;

  List<String> allDetails = ["0", "0", "0", "0"];

  List<Map<String, dynamic>>? records;

  int totalIncome = 0;
  int totalExpense = 0;

  int cashIncome = 0;
  int cashExpense = 0;

  int onlineIncome = 0;
  int onlineExpense = 0;

  int currentBalance = 0;

  String biggestCategory = "No Data";
  int biggestCategoryAmount = 0;

  int highestTransaction = 0;

  Future<void> getDetails() async {
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();

      String phoneNumber = sp.getString("phone_number")!;

      allDetails = await getAllInformation(phoneNumber);

      records = (await allRecords(phoneNumber, "All"))?.reversed.toList();

      name = sp.getString("username") ?? "";

      _calculateValues();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _calculateValues() {
    cashExpense = int.tryParse(allDetails[0]) ?? 0;

    cashIncome = int.tryParse(allDetails[1]) ?? 0;

    onlineExpense = int.tryParse(allDetails[2]) ?? 0;

    onlineIncome = int.tryParse(allDetails[3]) ?? 0;

    totalIncome = cashIncome + onlineIncome;

    totalExpense = cashExpense + onlineExpense;

    currentBalance = totalIncome - totalExpense;

    highestTransaction = 0;

    Map<String, int> categoryTotals = {};

    if (records != null) {
      for (var record in records!) {
        String paymentMode = record["Payment_Mode"].toString();

        int amount = int.tryParse(record["Amount"].toString()) ?? 0;

        bool isIncome =
            paymentMode == "Add CASH" || paymentMode == "Add Online";

        if (!isIncome) {
          String category = record["Category"].toString();

          categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
        }

        if (amount > highestTransaction && !isIncome) {
          highestTransaction = amount;
        }
      }
    }

    biggestCategory = "No Data";
    biggestCategoryAmount = 0;

    categoryTotals.forEach((category, amount) {
      if (amount > biggestCategoryAmount) {
        biggestCategoryAmount = amount;

        biggestCategory = category;
      }
    });
  }

  String money(int value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF2),

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,

        title: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                "assets/image/AccountApplicationLogo.jpg",
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome 👋",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),

                  Text(
                    name ?? "",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          RefreshIndicator(
            color: themeColor,
            onRefresh: getDetails,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.all(16),

              child: Column(
                children: [
                  // BALANCE CARD
                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(24),

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),

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
                        const Text(
                          "Current Balance",
                          style: TextStyle(color: Colors.white70),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          money(currentBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              "${money(totalIncome)} Income",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      _statCard(
                        "Income",
                        totalIncome,
                        Icons.arrow_downward,
                        Colors.green,
                      ),

                      _statCard(
                        "Expense",
                        totalExpense,
                        Icons.arrow_upward,
                        Colors.red,
                      ),

                      _statCard(
                        "Cash",
                        cashIncome - cashExpense,
                        Icons.account_balance_wallet,
                        Colors.blue,
                      ),

                      _statCard(
                        "Online",
                        onlineIncome - onlineExpense,
                        Icons.credit_card,
                        Colors.orange,
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Quick Insights",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _insightCard(
                        Icons.category,
                        "Biggest Expense",
                        biggestCategory,
                      ),

                      _insightCard(
                        Icons.currency_rupee,
                        "Highest Transaction",
                        money(highestTransaction),
                      ),

                      _insightCard(
                        Icons.receipt_long,
                        "Transactions",
                        "${records?.length ?? 0}",
                      ),

                      _insightCard(
                        Icons.account_balance,
                        "Balance",
                        money(currentBalance),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Recent Transactions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  (records != null && records!.isNotEmpty)
                      ? ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: records!.length > 5
                              ? 5
                              : records!.length,
                          itemBuilder: (context, index) {
                            bool isIncome =
                                records![index]["Payment_Mode"] == "Add CASH" ||
                                records![index]["Payment_Mode"] == "Add Online";

                            int amount =
                                int.tryParse(
                                  records![index]["Amount"].toString(),
                                ) ??
                                0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),

                              padding: const EdgeInsets.all(14),

                              decoration: BoxDecoration(
                                color: Colors.white,

                                borderRadius: BorderRadius.circular(20),

                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),

                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isIncome
                                        ? Colors.green.withOpacity(.12)
                                        : Colors.red.withOpacity(.12),

                                    child: Icon(
                                      isIncome
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,

                                      color: isIncome
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,

                                      children: [
                                        Text(
                                          records![index]["Category"]
                                              .toString(),

                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),

                                        const SizedBox(height: 3),

                                        Text(
                                          records![index]["Description"]
                                              .toString(),

                                          maxLines: 1,

                                          overflow: TextOverflow.ellipsis,

                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),

                                        const SizedBox(height: 5),

                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),

                                          decoration: BoxDecoration(
                                            color: themeColor.withOpacity(.12),

                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),

                                          child: Text(
                                            records![index]["Payment_Mode"]
                                                .toString(),

                                            style: TextStyle(
                                              color: themeColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,

                                    children: [
                                      Text(
                                        isIncome
                                            ? "+${money(amount)}"
                                            : "-${money(amount)}",

                                        style: TextStyle(
                                          color: isIncome
                                              ? Colors.green
                                              : Colors.red,

                                          fontWeight: FontWeight.bold,

                                          fontSize: 16,
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      Text(
                                        records![index]["Date"].toString(),

                                        style: TextStyle(
                                          color: Colors.grey.shade500,

                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: Text(
                            "No Transactions Found",
                            style: TextStyle(
                              color: themeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black.withOpacity(.25),

              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: CircularProgressIndicator(color: themeColor),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddSpent()),
          ) ?? false;

          if (result) {
            getDetails();
          }
        },

        backgroundColor: themeColor,

        elevation: 8,

        icon: const Icon(Icons.add, color: Colors.white),

        label: const Text(
          "Add",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _statCard(String title, int amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,

        children: [
          CircleAvatar(
            radius: 22,

            backgroundColor: color.withOpacity(.12),

            child: Icon(icon, color: color),
          ),

          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),

          FittedBox(
            child: Text(
              money(amount),

              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,

        children: [
          Icon(icon, color: themeColor, size: 30),

          Text(
            value,
            textAlign: TextAlign.center,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),

          Text(
            title,
            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
