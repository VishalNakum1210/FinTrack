import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/user_pages/add_spent.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/widgets/insight_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserMainPage extends StatefulWidget {
  const UserMainPage({super.key});

  @override
  State<UserMainPage> createState() => _UserMainPageState();
}

class _UserMainPageState extends State<UserMainPage> {
  final Color themeColor = CategoryTheme.primaryGreen;

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
      context.read<UserProvider>().loadUserSession();
      context.read<ExpenseProvider>().fetchExpenses(phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpenseProvider, UserProvider>(
      builder: (context, expenseProvider, userProvider, _) {
        final records = expenseProvider.records;
        final totalIncome = expenseProvider.totalIncome;
        final totalExpense = expenseProvider.totalExpense;
        final currentBalance = expenseProvider.currentBalance;
        final cashBalance = expenseProvider.addCash - expenseProvider.spentCash;
        final onlineBalance = expenseProvider.addOnline - expenseProvider.spentOnline;
        final isLoading = expenseProvider.isLoading;

        // Calculate highest transaction & biggest category
        String biggestCategory = "No Data";
        int biggestCategoryAmount = 0;
        int highestTransaction = 0;

        for (var record in records) {
          final mode = (record["Payment_Mode"] ?? "").toString();
          final amount = (double.tryParse(record["Amount"]?.toString() ?? '0') ?? 0.0).round();
          if (!mode.startsWith("Add")) {
            if (amount > highestTransaction) {
              highestTransaction = amount;
            }
          }
        }

        expenseProvider.categoryTotals.forEach((cat, amount) {
          if (amount > biggestCategoryAmount) {
            biggestCategoryAmount = amount;
            biggestCategory = cat;
          }
        });

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
                        userProvider.name,
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
                onRefresh: _loadData,
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
                              currentBalance.toINR(),
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
                                  "${totalIncome.toINR()} Income",
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
                            Icons.trending_up_rounded,
                            Colors.green,
                          ),
                          _statCard(
                            "Expense",
                            totalExpense,
                            Icons.trending_down_rounded,
                            Colors.red,
                          ),
                          _statCard(
                            "Cash",
                            cashBalance,
                            Icons.payments_rounded,
                            Colors.blue,
                          ),
                          _statCard(
                            "Online",
                            onlineBalance,
                            Icons.credit_card_rounded,
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
                          InsightCard(
                            icon: Icons.shopping_bag_outlined,
                            title: "Biggest Expense",
                            value: biggestCategory,
                            iconColor: themeColor,
                          ),
                          InsightCard(
                            icon: Icons.arrow_upward_rounded,
                            title: "Highest Transaction",
                            value: highestTransaction.toINR(),
                            iconColor: themeColor,
                          ),
                          InsightCard(
                            icon: Icons.receipt_long_outlined,
                            title: "Transactions",
                            value: "${records.length}",
                            iconColor: themeColor,
                          ),
                          InsightCard(
                            icon: Icons.account_balance_wallet_outlined,
                            title: "Balance",
                            value: currentBalance.toINR(),
                            iconColor: themeColor,
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

                      records.isNotEmpty
                          ? ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: records.length > 5 ? 5 : records.length,
                              itemBuilder: (context, index) {
                                final record = records[index];
                                final paymentMode = (record["Payment_Mode"] ?? "").toString();
                                final isIncome = paymentMode == "Add CASH" || paymentMode == "Add Online";
                                final amount = (double.tryParse(record["Amount"]?.toString() ?? '0') ?? 0.0).round();

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: .05),
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
                                            ? Colors.green.withValues(alpha: .12)
                                            : Colors.red.withValues(alpha: .12),
                                        child: Icon(
                                          isIncome
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          color: isIncome ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (record["Category"] ?? "Expense").toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              (record["Description"] ?? "").toString(),
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
                                                color: themeColor.withValues(alpha: .12),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                paymentMode,
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
                                            isIncome ? "+${amount.toINR()}" : "-${amount.toINR()}",
                                            style: TextStyle(
                                              color: isIncome ? Colors.green : Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            (record["Date"] ?? "").toString(),
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
                              height: 180,
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
                  color: Colors.black.withValues(alpha: .25),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddSpent()),
              );
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
      },
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
            color: Colors.black.withValues(alpha: .05),
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

            backgroundColor: color.withValues(alpha: .12),

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
              amount.toINR(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
