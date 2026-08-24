import 'package:FinTrack/GetInformation/SessionManager.dart';
import 'package:FinTrack/providers/expense_provider.dart';
import 'package:FinTrack/providers/friend_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class Reportpage extends StatefulWidget {
  const Reportpage({super.key});

  @override
  State<Reportpage> createState() => _ReportPageState();
}

class _ReportPageState extends State<Reportpage> {
  final Color themeColor = const Color(0xFF8BC24A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (mounted && phone.isNotEmpty) {
      context.read<ExpenseProvider>().fetchExpenses(phone);
      context.read<FriendProvider>().fetchFriends(phone);
    }
  }

  double calculateHealthScore(double totalIncome, double totalExpense) {
    if (totalIncome <= 0) return 0;
    return ((totalIncome - totalExpense) / totalIncome).clamp(0.0, 1.0);
  }

  String getHealthText(double healthScore) {
    if (healthScore >= .8) return "Excellent";
    if (healthScore >= .6) return "Good";
    if (healthScore >= .4) return "Average";
    return "Needs Improvement";
  }

  String money(num value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpenseProvider, FriendProvider>(
      builder: (context, expenseProvider, friendProvider, _) {
        final isLoading = expenseProvider.isLoading || friendProvider.isLoading;
        final totalIncome = expenseProvider.totalIncome.toDouble();
        final totalExpense = expenseProvider.totalExpense.toDouble();
        final currentBalance = expenseProvider.currentBalance.toDouble();
        final cashBalance = (expenseProvider.addCash - expenseProvider.spentCash).toDouble();
        final onlineBalance = (expenseProvider.addOnline - expenseProvider.spentOnline).toDouble();
        final friendGiven = friendProvider.totalGet.toDouble();
        final friendTaken = friendProvider.totalGive.toDouble();
        final categoryTotals = expenseProvider.categoryTotals.map((k, v) => MapEntry(k, v.toDouble()));
        final recentTransactions = expenseProvider.records;
        final transactionCount = recentTransactions.length;

        final healthScore = calculateHealthScore(totalIncome, totalExpense);
        final healthText = getHealthText(healthScore);

        String topCategory = "No Data";
        if (categoryTotals.isNotEmpty) {
          topCategory = categoryTotals.entries
              .reduce((a, b) => (a.value > b.value) ? a : b)
              .key;
        }

        double highestIncome = 0;
        for (var r in recentTransactions) {
          final mode = (r["Payment_Mode"] ?? "").toString();
          final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;
          if (mode.startsWith("Add") && amt > highestIncome) {
            highestIncome = amt;
          }
        }

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
          body: SingleChildScrollView(
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
                        colors: [themeColor, themeColor.withValues(alpha: .75)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withValues(alpha: .25),
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
                        icon: Icons.payments_rounded,
                        title: "Cash Balance",
                        value: money(cashBalance),
                      ),
                      _insightCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: "Online Balance",
                        value: money(onlineBalance),
                      ),
                      _insightCard(
                        icon: Icons.shopping_bag,
                        title: "Biggest Expense",
                        value: topCategory,
                      ),
                      _insightCard(
                        icon: Icons.monetization_on,
                        title: "Highest Income",
                        value: money(highestIncome),
                      ),
                      _insightCard(
                        icon: Icons.receipt_long,
                        title: "Transactions",
                        value: transactionCount.toString(),
                      ),
                      _insightCard(
                        icon: Icons.calendar_month,
                        title: "Total Records",
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
                      amount: money(e.value),
                      value: totalExpense > 0
                          ? (e.value / totalExpense).clamp(0.0, 1.0)
                          : 0.0,
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
                            const Text("Money You Get"),
                            Text(
                              money(friendGiven),
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
                              money(friendTaken),
                              style: const TextStyle(
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
                          final payment = (record["Payment_Mode"] ?? record["payment"] ?? "").toString();
                          final category = (record["Category"] ?? record["category"] ?? "Other").toString();
                          final amt = double.tryParse(record["Amount"]?.toString() ?? record["amount"]?.toString() ?? '0') ?? 0.0;
                          bool isExpense = payment.contains("Spent");

                          return _activityTile(
                            themeColor,
                            isExpense
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            category,
                            "${isExpense ? "-" : "+"}${money(amt)}",
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
      },
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .05),
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
                backgroundColor: themeColor.withValues(alpha: .15),
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
            backgroundColor: themeColor.withValues(alpha: .15),
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
