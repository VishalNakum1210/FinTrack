import 'package:fin_track/friends_pages/split_bill_page.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/profile_pages/report_page.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/user_pages/add_spent.dart';
import 'package:fin_track/utils/balance_helper.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:fin_track/widgets/confirm_dialog.dart';
import 'package:fin_track/widgets/edit_expense_modal.dart';
import 'package:fin_track/widgets/error_retry_widget.dart';
import 'package:fin_track/widgets/passbook_transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UserMainPage extends StatefulWidget {
  const UserMainPage({super.key});

  @override
  State<UserMainPage> createState() => _UserMainPageState();
}

class _UserMainPageState extends State<UserMainPage> {
  final Color themeColor = CategoryTheme.primaryGreen;
  bool _isLoadingData = false;
  bool _isPullRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Good morning 🌅";
    } else if (hour >= 12 && hour < 17) {
      return "Good afternoon ☀️";
    } else if (hour >= 17 && hour < 21) {
      return "Good evening 🌆";
    } else {
      return "Good night 🌙";
    }
  }

  Future<void> _loadData({bool force = false}) async {
    if (_isLoadingData && !force) return;
    if (mounted) {
      setState(() => _isLoadingData = true);
    } else {
      _isLoadingData = true;
    }
    try {
      final phone = await SessionManager.getPhoneNumber() ?? "";
      if (mounted && phone.isNotEmpty) {
        context.read<UserProvider>().loadUserSession();
        context.read<ExpenseProvider>().fetchExpenses(phone, force: force);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      } else {
        _isLoadingData = false;
      }
    }
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> item) {
    final category = (item["Category"] ?? "Other").toString();
    final desc = (item["Description"] ?? "No description").toString();
    final method = (item["Payment_Mode"] ?? "").toString();
    final amount = double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0;
    final date = (item["Date"] ?? "").toString();
    final isIncome = ["Add CASH", "Add Online"].contains(method);
    final key = (item["key"] ?? "").toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 30,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: CategoryTheme.getBgColor(category),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    CategoryTheme.getIcon(category),
                    color: CategoryTheme.getColor(category),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        DateHelper.formatDisplay(date),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  isIncome ? "+${amount.toINR()}" : "-${amount.toINR()}",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isIncome ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            if (desc.isNotEmpty) ...[
              const Text(
                "Description / Merchant",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              "Payment Mode",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              method,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        backgroundColor: Colors.red.shade50.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final confirmed = await showDeleteConfirmDialog(
                          context,
                          title: "Delete Record",
                          message: "Are you sure you want to delete this record?",
                        );
                        if (confirmed == true && key.isNotEmpty) {
                          final phone = await SessionManager.getPhoneNumber() ?? "";
                          if (context.mounted && phone.isNotEmpty) {
                            await context.read<ExpenseProvider>().deleteExpense(phoneNumber: phone, key: key);
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8BC24A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text("Edit", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final result = await showEditExpenseModal(context: context, record: item);
                        if (result == true && mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpenseProvider, UserProvider>(
      builder: (context, expenseProvider, userProvider, _) {
        final records = expenseProvider.records;
        final totalIncome = expenseProvider.totalIncome;
        final totalExpense = expenseProvider.totalExpense;
        final currentBalance = expenseProvider.currentBalance;
        final cashBalance = expenseProvider.cashBalance;
        final onlineBalance = expenseProvider.onlineBalance;
        final isLoading = expenseProvider.isLoading;
        final biggestCategory = expenseProvider.biggestCategory;
        final highestTransaction = expenseProvider.highestTransaction;

        // Calculate 7-day spending trend vs previous 7 days
        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        final fourteenDaysAgo = now.subtract(const Duration(days: 14));
        double last7Expense = 0;
        double prev7Expense = 0;
        for (final r in records) {
          final mode = (r["Payment_Mode"] ?? "").toString();
          final isExpense = mode != "Add CASH" && mode != "Add Online";
          if (isExpense) {
            final date = (r["_parsedDate"] as DateTime?) ?? DateHelper.parse(r["Date"]);
            if (date != null) {
              final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;
              if (date.isAfter(sevenDaysAgo)) {
                last7Expense += amt;
              } else if (date.isAfter(fourteenDaysAgo)) {
                prev7Expense += amt;
              }
            }
          }
        }

        // Compute running balances for recent transaction cards (L3 DRY fix)
        BalanceHelper.computeRunningBalances(records);

        // Recent 5 transactions (newest first)
        final recentRecords = List<Map<String, dynamic>>.from(records);
        recentRecords.sort((a, b) {
          final DateTime? dateA = (a["_parsedDate"] as DateTime?) ?? DateHelper.parse(a["Date"]);
          final DateTime? dateB = (b["_parsedDate"] as DateTime?) ?? DateHelper.parse(b["Date"]);
          int cmp = 0;
          if (dateA != null && dateB != null) {
            cmp = dateB.compareTo(dateA);
          } else if (dateA != null) {
            cmp = -1;
          } else if (dateB != null) {
            cmp = 1;
          }
          if (cmp != 0) return cmp;
          final tA = (a["timestamp"] as num?)?.toInt() ?? 0;
          final tB = (b["timestamp"] as num?)?.toInt() ?? 0;
          return tB.compareTo(tA);
        });
        final displayRecent = recentRecords.take(5).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            titleSpacing: 16,
            title: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                        _getGreeting(),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        userProvider.name.isNotEmpty ? "${userProvider.name} 👋" : "User 👋",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: "Refresh Data",
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.refresh_rounded, color: themeColor, size: 20),
                ),
                onPressed: () => _loadData(force: true),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                color: themeColor,
                onRefresh: () async {
                  setState(() => _isPullRefreshing = true);
                  await _loadData(force: true);
                  if (mounted) setState(() => _isPullRefreshing = false);
                },
                child: (expenseProvider.hasError && records.isEmpty)
                    ? ErrorRetryWidget(
                        message: expenseProvider.errorMessage,
                        primaryColor: themeColor,
                        onRetry: () => _loadData(force: true),
                      )
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. HERO BALANCE CARD
                            _buildHeroBalanceCard(
                              currentBalance: currentBalance,
                              totalIncome: totalIncome,
                              totalExpense: totalExpense,
                              bankBalance: onlineBalance,
                              cashBalance: cashBalance,
                              last7Expense: last7Expense,
                              prev7Expense: prev7Expense,
                            ),
                            const SizedBox(height: 16),

                            // 2. QUICK ACTION BAR
                            _buildQuickActionBar(),
                            const SizedBox(height: 20),

                            // 3. QUICK INSIGHTS SECTION (2x2 Grid)
                            const Text(
                              "Quick Insights",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildQuickInsightsGrid(
                              biggestCategory: biggestCategory,
                              highestTransaction: highestTransaction,
                              totalTransactions: records.length,
                              cashBalance: cashBalance,
                              onlineBalance: onlineBalance,
                            ),
                            const SizedBox(height: 22),

                            // 4. RECENT TRANSACTIONS SECTION
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Recent Transactions",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (records.isNotEmpty)
                                  Text(
                                    "Showing last 5",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (displayRecent.isEmpty)
                              _buildEmptyTransactions()
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayRecent.length,
                                itemBuilder: (context, index) {
                                  final record = displayRecent[index];
                                  final category = (record["Category"] ?? "Other").toString();
                                  final desc = (record["Description"] ?? "").toString();
                                  final paymentMode = (record["Payment_Mode"] ?? "").toString();
                                  final isIncome = ["Add CASH", "Add Online"].contains(paymentMode);
                                  final amount = double.tryParse(record["Amount"]?.toString() ?? '0') ?? 0.0;
                                  final date = (record["Date"] ?? "").toString();
                                  final runningBal = record["_runningBalance"] as double?;
                                  final splitFriend = record["splitFriend"]?.toString();

                                  return PassbookTransactionTile(
                                    category: category,
                                    description: desc,
                                    paymentMode: paymentMode,
                                    time: DateHelper.formatDisplay(date),
                                    amount: amount,
                                    isIncome: isIncome,
                                    runningBalance: runningBal,
                                    splitFriendName: splitFriend,
                                    onTap: () => _showTransactionDetails(context, record),
                                    onEdit: () async {
                                      final result = await showEditExpenseModal(context: context, record: record);
                                      if (result == true && mounted) {
                                        setState(() {});
                                      }
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
              ),

              if (isLoading && !_isPullRefreshing)
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
            heroTag: "dashboard_fab",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddSpent()),
              );
            },
            backgroundColor: themeColor,
            elevation: 4,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            label: const Text(
              "Add Spent",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroBalanceCard({
    required int currentBalance,
    required int totalIncome,
    required int totalExpense,
    required int bankBalance,
    required int cashBalance,
    required double last7Expense,
    required double prev7Expense,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8BC24A), Color(0xFF689F38)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF689F38).withValues(alpha: .30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title + Weekly Trend Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Balance",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (last7Expense > 0 || prev7Expense > 0) ...[
                () {
                  final diff = (last7Expense - prev7Expense).round();
                  final bool isDecrease = diff < 0;
                  final bool isSame = diff == 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSame
                              ? Icons.trending_flat_rounded
                              : (isDecrease
                                  ? Icons.trending_down_rounded
                                  : Icons.trending_up_rounded),
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSame
                              ? "Same as last wk"
                              : (isDecrease
                                  ? "-${diff.abs().toINR()} vs last wk"
                                  : "+${diff.toINR()} vs last wk"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }(),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Main Balance
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currentBalance.toINR(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Dual Account Pills: Bank / Online & Cash in Hand
          Row(
            children: [
              // Bank Account Pill
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Bank / Online",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                bankBalance.toINR(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Cash in Hand Pill
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Cash in Hand",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                cashBalance.toINR(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Bottom Dual Inflow / Outflow Capsules
          Row(
            children: [
              // Inflow Capsule
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Income",
                              style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "+${totalIncome.toINR()}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Outflow Capsule
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Expense",
                              style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "-${totalExpense.toINR()}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBar() {
    return Row(
      children: [
        _buildActionItem(
          icon: Icons.add_circle_outline_rounded,
          label: "Add Spend",
          color: themeColor,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddSpent()),
            );
          },
        ),
        const SizedBox(width: 10),
        _buildActionItem(
          icon: Icons.call_split_rounded,
          label: "Split Bill",
          color: const Color(0xFF7C3AED),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SplitBillPage()),
            );
          },
        ),
        const SizedBox(width: 10),
        _buildActionItem(
          icon: Icons.analytics_outlined,
          label: "Reports",
          color: const Color(0xFF0288D1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Reportpage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInsightsGrid({
    required String biggestCategory,
    required int highestTransaction,
    required int totalTransactions,
    required int cashBalance,
    required int onlineBalance,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.32,
      children: [
        _buildInsightCard(
          icon: Icons.shopping_bag_outlined,
          title: "Top Category",
          value: biggestCategory.isNotEmpty ? biggestCategory : "None",
          iconColor: const Color(0xFFE65100),
          bgColor: const Color(0xFFFFF3E0),
        ),
        _buildInsightCard(
          icon: Icons.arrow_upward_rounded,
          title: "Highest Spend",
          value: highestTransaction > 0 ? highestTransaction.toINR() : "₹0",
          iconColor: const Color(0xFFC62828),
          bgColor: const Color(0xFFFFEBEE),
        ),
        _buildInsightCard(
          icon: Icons.receipt_long_outlined,
          title: "Total Entries",
          value: "$totalTransactions recorded",
          iconColor: themeColor,
          bgColor: const Color(0xFFE8F5E9),
        ),
        _buildInsightCard(
          icon: Icons.account_balance_wallet_outlined,
          title: "Wallet Split",
          value: "Cash: ${cashBalance.toINR()}",
          subtitle: "Online: ${onlineBalance.toINR()}",
          iconColor: const Color(0xFF0288D1),
          bgColor: const Color(0xFFE1F5FE),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyTransactions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 36, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          const Text(
            "No Transactions Recorded Yet",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Tap '+ Add Spend' above to record your first expense or income.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
