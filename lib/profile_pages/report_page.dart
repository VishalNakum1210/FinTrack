import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:fin_track/widgets/insight_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

enum ReportPeriod { thisMonth, lastMonth, thisYear, allTime }

class Reportpage extends StatefulWidget {
  const Reportpage({super.key});

  @override
  State<Reportpage> createState() => _ReportPageState();
}

class _ReportPageState extends State<Reportpage> {
  final Color themeColor = CategoryTheme.darkGreen;
  ReportPeriod selectedPeriod = ReportPeriod.thisMonth;
  int _touchedPieIndex = -1;

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

  bool _matchesPeriod(DateTime? date, ReportPeriod period) {
    if (period == ReportPeriod.allTime) return true;
    if (date == null) return false;

    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.thisMonth:
        return date.year == now.year && date.month == now.month;
      case ReportPeriod.lastMonth:
        final lastMonthDate = DateTime(now.year, now.month - 1);
        return date.year == lastMonthDate.year && date.month == lastMonthDate.month;
      case ReportPeriod.thisYear:
        return date.year == now.year;
      case ReportPeriod.allTime:
        return true;
    }
  }

  String _getPeriodLabel(ReportPeriod period) {
    switch (period) {
      case ReportPeriod.thisMonth:
        return "This Month";
      case ReportPeriod.lastMonth:
        return "Last Month";
      case ReportPeriod.thisYear:
        return "This Year";
      case ReportPeriod.allTime:
        return "All Time";
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

  Future<void> exportReportToPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> records,
    required int income,
    required int expense,
    required int balance,
    required int addCash,
    required int spentCash,
    required int addOnline,
    required int spentOnline,
    required int friendGet,
    required int friendGive,
    required Map<String, double> categoryTotals,
  }) async {
    final userProvider = context.read<UserProvider>();
    final userName = userProvider.name.isNotEmpty ? userProvider.name : "User";
    final phone = userProvider.phoneNumber;

    Fluttertoast.showToast(msg: "Generating Financial Report PDF...");
    await ExportService.exportReportPdf(
      userName: userName,
      phoneNumber: phone,
      totalIncome: income,
      totalExpense: expense,
      currentBalance: balance,
      addCash: addCash,
      spentCash: spentCash,
      addOnline: addOnline,
      spentOnline: spentOnline,
      friendGet: friendGet,
      friendGive: friendGive,
      categoryTotals: categoryTotals,
      records: records,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExpenseProvider, FriendProvider>(
      builder: (context, expenseProvider, friendProvider, _) {
        final isLoading = expenseProvider.isLoading || friendProvider.isLoading;
        final allRecords = expenseProvider.records;

        // 1. Filter Records based on Period
        final filteredRecords = allRecords.where((r) {
          final d = (r["_parsedDate"] as DateTime?) ?? DateHelper.parse(r["Date"]);
          return _matchesPeriod(d, selectedPeriod);
        }).toList();

        // 2. Compute Filtered Metrics
        double periodIncome = 0;
        double periodExpense = 0;
        int periodCashSpent = 0;
        int periodOnlineSpent = 0;
        int periodCashAdded = 0;
        int periodOnlineAdded = 0;
        double highestIncome = 0;
        final Map<String, double> periodCategoryTotals = {};

        for (var r in filteredRecords) {
          final mode = (r["Payment_Mode"] ?? "").toString();
          final category = (r["Category"] ?? "Other").toString();
          final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;

          if (mode == "Add CASH") {
            periodIncome += amt;
            periodCashAdded += amt.toInt();
            if (amt > highestIncome) highestIncome = amt;
          } else if (mode == "Add Online") {
            periodIncome += amt;
            periodOnlineAdded += amt.toInt();
            if (amt > highestIncome) highestIncome = amt;
          } else if (mode == "Spent Cash") {
            periodExpense += amt;
            periodCashSpent += amt.toInt();
            periodCategoryTotals[category] = (periodCategoryTotals[category] ?? 0) + amt;
          } else if (mode == "Spent Online") {
            periodExpense += amt;
            periodOnlineSpent += amt.toInt();
            periodCategoryTotals[category] = (periodCategoryTotals[category] ?? 0) + amt;
          } else {
            periodExpense += amt;
            periodCategoryTotals[category] = (periodCategoryTotals[category] ?? 0) + amt;
          }
        }

        final periodBalance = periodIncome - periodExpense;
        final healthScore = calculateHealthScore(periodIncome, periodExpense);
        final healthText = getHealthText(healthScore);
        final savingsRate = periodIncome > 0
            ? (((periodIncome - periodExpense) / periodIncome) * 100).clamp(0, 100)
            : 0.0;

        String topCategory = "None";
        if (periodCategoryTotals.isNotEmpty) {
          topCategory = periodCategoryTotals.entries
              .reduce((a, b) => (a.value > b.value) ? a : b)
              .key;
        }

        final friendGiven = friendProvider.totalGet.toDouble();
        final friendTaken = friendProvider.totalGive.toDouble();

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
              "Financial Reports",
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                tooltip: "Export Statement (PDF)",
                icon: Icon(Icons.picture_as_pdf, color: themeColor),
                onPressed: () {
                  exportReportToPdf(
                    context: context,
                    records: filteredRecords,
                    income: periodIncome.toInt(),
                    expense: periodExpense.toInt(),
                    balance: periodBalance.toInt(),
                    addCash: periodCashAdded,
                    spentCash: periodCashSpent,
                    addOnline: periodOnlineAdded,
                    spentOnline: periodOnlineSpent,
                    friendGet: friendGiven.toInt(),
                    friendGive: friendTaken.toInt(),
                    categoryTotals: periodCategoryTotals,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Period Selector Chips
                _buildPeriodSelector(),

                const SizedBox(height: 16),

                // 2. Hero Gradient Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [themeColor, themeColor.withValues(alpha: 0.82)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_getPeriodLabel(selectedPeriod)} Net Balance",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${filteredRecords.length} records",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        periodBalance.toINR(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            periodBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Savings Rate: ${savingsRate.toStringAsFixed(0)}% ($healthText)",
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Health Score Gauge Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 68,
                        height: 68,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: healthScore,
                              backgroundColor: themeColor.withValues(alpha: 0.15),
                              color: healthScore >= 0.5 ? themeColor : Colors.orange,
                              strokeWidth: 7,
                            ),
                            Text(
                              "${(healthScore * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Financial Health Score",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$healthText - ${healthScore >= 0.6 ? 'Healthy savings & low expense ratio' : 'Consider reviewing major expense categories'}",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. Interactive Cashflow Comparison Bar Chart
                _buildCashflowBarChart(
                  income: periodIncome,
                  expense: periodExpense,
                  cashIn: periodCashAdded,
                  cashOut: periodCashSpent,
                  onlineIn: periodOnlineAdded,
                  onlineOut: periodOnlineSpent,
                ),

                const SizedBox(height: 20),

                // 5. Quick Insights Grid
                const Text(
                  "Quick Insights",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.35,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    InsightCard(
                      icon: Icons.payments_rounded,
                      title: "Cash Spent",
                      value: periodCashSpent.toINR(),
                      iconColor: themeColor,
                    ),
                    InsightCard(
                      icon: Icons.account_balance_wallet_rounded,
                      title: "Online Spent",
                      value: periodOnlineSpent.toINR(),
                      iconColor: themeColor,
                    ),
                    InsightCard(
                      icon: Icons.shopping_bag_outlined,
                      title: "Top Category",
                      value: topCategory,
                      iconColor: themeColor,
                    ),
                    InsightCard(
                      icon: Icons.arrow_upward_rounded,
                      title: "Highest Income",
                      value: highestIncome.toINR(),
                      iconColor: themeColor,
                    ),
                    InsightCard(
                      icon: Icons.savings_outlined,
                      title: "Savings Rate",
                      value: "${savingsRate.toStringAsFixed(0)}%",
                      iconColor: themeColor,
                    ),
                    InsightCard(
                      icon: Icons.receipt_long_outlined,
                      title: "Transactions",
                      value: "${filteredRecords.length} records",
                      iconColor: themeColor,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 6. Interactive Category Donut / Breakdown Chart
                _buildCategoryDonutSection(periodCategoryTotals, periodExpense),

                const SizedBox(height: 20),

                // 7. Friend Ledger Summary
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded, color: themeColor),
                          const SizedBox(width: 10),
                          const Text(
                            "Friend Ledger Overview",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Money You Will Receive"),
                          Text(
                            friendGiven.toINR(),
                            style: TextStyle(
                              color: themeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Money You Owe (To Give)"),
                          Text(
                            friendTaken.toINR(),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Net Friend Settlement",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            (friendGiven - friendTaken).toINR(),
                            style: TextStyle(
                              color: (friendGiven < friendTaken) ? Colors.red : themeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 8. Recent Transactions Stream
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Period Activity",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${filteredRecords.take(5).length} of ${filteredRecords.length}",
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (filteredRecords.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              "No transactions recorded for this period.",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ...filteredRecords.take(5).map((record) {
                          final payment = (record["Payment_Mode"] ?? "").toString();
                          final category = (record["Category"] ?? "Other").toString();
                          final date = (record["Date"] ?? "-").toString();
                          final amt = double.tryParse(record["Amount"]?.toString() ?? '0') ?? 0.0;
                          final isIncome = payment.startsWith("Add");

                          return _activityTile(
                            themeColor: themeColor,
                            icon: isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            title: category,
                            subtitle: "$date • $payment",
                            amount: "${isIncome ? '+' : '-'}${amt.toINR()}",
                            amountColor: isIncome ? themeColor : Colors.red,
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

  // ===========================================================================
  // 📊 VISUAL CHARTS BUILDERS
  // ===========================================================================

  Widget _buildCashflowBarChart({
    required double income,
    required double expense,
    required int cashIn,
    required int cashOut,
    required int onlineIn,
    required int onlineOut,
  }) {
    final maxVal = [income, expense, cashIn.toDouble(), cashOut.toDouble(), onlineIn.toDouble(), onlineOut.toDouble()]
        .reduce((a, b) => a > b ? a : b);
    final double maxY = maxVal > 0 ? maxVal * 1.25 : 1000;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Cashflow Comparison",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  _legendDot(themeColor, "Inflow"),
                  const SizedBox(width: 10),
                  _legendDot(const Color(0xFFEF5350), "Outflow"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.grey.shade900,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final title = groupIndex == 0
                          ? "Total"
                          : groupIndex == 1
                              ? "Cash"
                              : "Online";
                      final isIncome = rodIndex == 0;
                      return BarTooltipItem(
                        "$title ${isIncome ? 'In' : 'Out'}\n",
                        const TextStyle(color: Colors.white70, fontSize: 11),
                        children: [
                          TextSpan(
                            text: rod.toY.toINR(),
                            style: TextStyle(
                              color: isIncome ? Colors.greenAccent : const Color(0xFFFF8A80),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        String text = "";
                        switch (value.toInt()) {
                          case 0:
                            text = "Overall";
                            break;
                          case 1:
                            text = "Cash";
                            break;
                          case 2:
                            text = "Online";
                            break;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            text,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, income, expense),
                  _makeBarGroup(1, cashIn.toDouble(), cashOut.toDouble()),
                  _makeBarGroup(2, onlineIn.toDouble(), onlineOut.toDouble()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double inVal, double outVal) {
    return BarChartGroupData(
      x: x,
      barsSpace: 6,
      barRods: [
        BarChartRodData(
          toY: inVal,
          color: themeColor,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
        BarChartRodData(
          toY: outVal,
          color: const Color(0xFFEF5350),
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      ],
    );
  }

  Widget _buildCategoryDonutSection(Map<String, double> categoryTotals, double totalExpense) {
    if (categoryTotals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: _cardDecoration(),
        child: Center(
          child: Text(
            "No category expenses for ${_getPeriodLabel(selectedPeriod).toLowerCase()}.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      );
    }

    final entries = categoryTotals.entries.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Expense Distribution",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Donut Pie Chart with Interactive Center Label
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedPieIndex = -1;
                              return;
                            }
                            _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2.5,
                      centerSpaceRadius: 38,
                      sections: List.generate(entries.length, (i) {
                        final isTouched = i == _touchedPieIndex;
                        final double fontSize = isTouched ? 13 : 10;
                        final double radius = isTouched ? 48 : 40;
                        final entry = entries[i];
                        final share = totalExpense > 0 ? (entry.value / totalExpense) * 100 : 0.0;
                        final color = CategoryTheme.getColor(entry.key);

                        return PieChartSectionData(
                          color: color,
                          value: entry.value,
                          title: "${share.toStringAsFixed(0)}%",
                          radius: radius,
                          titleStyle: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: entries.take(4).map((e) {
                      final share = totalExpense > 0 ? (e.value / totalExpense) * 100 : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: CategoryTheme.getColor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "${share.toStringAsFixed(0)}%",
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Category Progress Bars List
          ...entries.map((e) {
            final share = totalExpense > 0 ? (e.value / totalExpense).clamp(0.0, 1.0) : 0.0;
            return _categoryTile(
              themeColor: CategoryTheme.getColor(e.key),
              icon: CategoryTheme.getIcon(e.key),
              title: e.key,
              amount: e.value.toINR(),
              percentage: (share * 100).toStringAsFixed(1),
              value: share,
            );
          }),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ReportPeriod.values.map((period) {
          final isSelected = selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getPeriodLabel(period)),
              selected: isSelected,
              selectedColor: themeColor,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? themeColor : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              onSelected: (_) {
                setState(() {
                  selectedPeriod = period;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _categoryTile({
    required Color themeColor,
    required IconData icon,
    required String title,
    required String amount,
    required String percentage,
    required double value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: themeColor.withValues(alpha: .15),
                child: Icon(icon, color: themeColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              Text(
                "$amount ($percentage%)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: value,
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
            backgroundColor: themeColor.withValues(alpha: .15),
            valueColor: AlwaysStoppedAnimation(themeColor),
          ),
        ],
      ),
    );
  }

  Widget _activityTile({
    required Color themeColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required Color amountColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: amountColor.withValues(alpha: .12),
            child: Icon(icon, color: amountColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
