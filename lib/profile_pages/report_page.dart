import 'package:fin_track/utils/money.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/date_helper.dart';
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
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF2E7D32);
  static const Color _canvasBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderGrey = Color(0xFFE2E8F0);

  ReportPeriod selectedPeriod = ReportPeriod.thisMonth;
  bool _showAdvancedCharts = false;
  int _touchedPieIndex = -1;

  bool _matchesPeriod(DateTime? date, ReportPeriod period) {
    if (period == ReportPeriod.allTime) return true;
    if (date == null) return false;

    final now = DateTime.now();
    switch (period) {
      case ReportPeriod.thisMonth:
        return date.year == now.year && date.month == now.month;
      case ReportPeriod.lastMonth:
        final lastMonthDate = DateTime(now.year, now.month - 1);
        return date.year == lastMonthDate.year &&
            date.month == lastMonthDate.month;
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
    return "Needs Work";
  }

  void _showHealthScoreExplanation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      color: _darkGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Health Score Formula",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                "Calculated based on your net savings rate for the selected period:",
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderGrey),
                ),
                child: const Center(
                  child: Text(
                    "Score = (Income - Expense) / Income × 100",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: _textDark,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _scoreGuideItem(
                "80% – 100%",
                "Excellent",
                "High savings discipline & low burn rate",
                const Color(0xFF2E7D32),
              ),
              _scoreGuideItem(
                "60% – 79%",
                "Good",
                "Healthy savings buffer maintained",
                _primaryGreen,
              ),
              _scoreGuideItem(
                "40% – 59%",
                "Average",
                "Moderate savings, review major expenses",
                Colors.orange,
              ),
              _scoreGuideItem(
                "< 40%",
                "Needs Work",
                "Expenses close to or exceeding income",
                const Color(0xFFC62828),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _scoreGuideItem(String range, String label, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              range,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$label: $desc",
              style: const TextStyle(fontSize: 12, color: _textDark),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> exportReportToPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> records,
    required double income,
    required double expense,
    required double balance,
    required double addCash,
    required double spentCash,
    required double addOnline,
    required double spentOnline,
    required double friendGet,
    required double friendGive,
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _borderGrey, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
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
          final d =
              (r["_parsedDate"] as DateTime?) ?? DateHelper.parse(r["Date"]);
          return _matchesPeriod(d, selectedPeriod);
        }).toList();

        // 2. Compute Filtered Metrics
        double periodIncome = 0.0;
        double periodExpense = 0.0;
        double periodCashSpent = 0.0;
        double periodOnlineSpent = 0.0;
        double periodCashAdded = 0.0;
        double periodOnlineAdded = 0.0;
        final Map<String, double> periodCategoryTotals = {};

        for (var r in filteredRecords) {
          final mode = (r["Payment_Mode"] ?? "").toString();
          final category = (r["Category"] ?? "Other").toString();
          final amt = Money.rupees(r["Amount"]);

          if (mode == "Add CASH") {
            periodIncome = Money.sum([periodIncome, amt]);
            periodCashAdded = Money.sum([periodCashAdded, amt]);
          } else if (mode == "Add Online") {
            periodIncome = Money.sum([periodIncome, amt]);
            periodOnlineAdded = Money.sum([periodOnlineAdded, amt]);
          } else if (mode == "Spent Cash") {
            periodExpense = Money.sum([periodExpense, amt]);
            periodCashSpent = Money.sum([periodCashSpent, amt]);
            periodCategoryTotals[category] = Money.sum([
              periodCategoryTotals[category] ?? 0,
              amt,
            ]);
          } else if (mode == "Spent Online") {
            periodExpense = Money.sum([periodExpense, amt]);
            periodOnlineSpent = Money.sum([periodOnlineSpent, amt]);
            periodCategoryTotals[category] = Money.sum([
              periodCategoryTotals[category] ?? 0,
              amt,
            ]);
          } else {
            periodExpense = Money.sum([periodExpense, amt]);
            periodCategoryTotals[category] = Money.sum([
              periodCategoryTotals[category] ?? 0,
              amt,
            ]);
          }
        }

        final periodBalance = periodIncome - periodExpense;
        final healthScore = calculateHealthScore(periodIncome, periodExpense);
        final healthText = getHealthText(healthScore);
        final double savingsRate = periodIncome > 0
            ? (((periodIncome - periodExpense) / periodIncome) * 100)
                  .clamp(0.0, 100.0)
                  .toDouble()
            : 0.0;

        // Friend Ledger Filtered Calculation
        double periodFriendGiven = 0.0;
        double periodFriendTaken = 0.0;
        bool hasFriendRecords = false;

        for (final f in friendProvider.friends) {
          final recordsObj = f["Records"];
          if (recordsObj is Map) {
            hasFriendRecords = true;
            recordsObj.forEach((rk, rv) {
              if (rv is Map) {
                final d = DateHelper.parse(rv["Date"]);
                if (_matchesPeriod(d, selectedPeriod)) {
                  final amt = Money.rupees(rv["Amount"]);
                  final type = rv["Type"]?.toString() ?? "";
                  if (type == "Take Money From Friend") {
                    periodFriendTaken = Money.sum([periodFriendTaken, amt]);
                  } else {
                    periodFriendGiven = Money.sum([periodFriendGiven, amt]);
                  }
                }
              }
            });
          }
        }

        final friendGiven =
            (hasFriendRecords && selectedPeriod != ReportPeriod.allTime)
            ? periodFriendGiven
            : friendProvider.totalGet.toDouble();
        final friendTaken =
            (hasFriendRecords && selectedPeriod != ReportPeriod.allTime)
            ? periodFriendTaken
            : friendProvider.totalGive.toDouble();

        void triggerPdfExport() {
          exportReportToPdf(
            context: context,
            records: filteredRecords,
            income: periodIncome,
            expense: periodExpense,
            balance: periodBalance,
            addCash: periodCashAdded,
            spentCash: periodCashSpent,
            addOnline: periodOnlineAdded,
            spentOnline: periodOnlineSpent,
            friendGet: friendGiven,
            friendGive: friendTaken,
            categoryTotals: periodCategoryTotals,
          );
        }

        if (isLoading) {
          return const Scaffold(
            backgroundColor: _canvasBg,
            appBar: null,
            body: Center(
              child: CircularProgressIndicator(color: _primaryGreen),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _canvasBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Financial Reports",
              style: TextStyle(
                color: _textDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  tooltip: "Export PDF Report",
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: _primaryGreen,
                    size: 20,
                  ),
                  onPressed: triggerPdfExport,
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // 1. Period Selector Tabs (Pill Segment)
                _buildPeriodSegment(),

                const SizedBox(height: 8),

                // 2. Financial Health Score Card
                _buildHealthScoreCard(healthScore, healthText, savingsRate),

                // 3. Cash Flow Overview Card
                _buildCashFlowCard(periodIncome, periodExpense, savingsRate),

                // 4. Spending by Category Card
                _buildSpendingByCategoryCard(
                  periodCategoryTotals,
                  periodExpense,
                ),

                // 5. Payment Mode Split Card
                _buildPaymentModeSplitCard(periodCashSpent, periodOnlineSpent),

                // 6. Friend Ledger Summary (if friends data exists)
                if (friendProvider.friends.isNotEmpty)
                  _buildFriendLedgerCard(friendGiven, friendTaken),

                // 7. Advanced Interactive Visual Charts (Collapsible)
                _buildAdvancedChartsToggle(
                  periodCategoryTotals,
                  periodExpense,
                  periodIncome,
                  periodExpense,
                  periodCashAdded,
                  periodCashSpent,
                  periodOnlineAdded,
                  periodOnlineSpent,
                ),

                const SizedBox(height: 8),

                // 8. Bottom Action CTA Button
                _buildExportButton(triggerPdfExport),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. PERIOD SELECTOR (Pill Segmented Control)
  // ===========================================================================
  Widget _buildPeriodSegment() {
    final periods = [
      ReportPeriod.thisMonth,
      ReportPeriod.lastMonth,
      ReportPeriod.thisYear,
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: periods.map((p) {
          final isSelected = selectedPeriod == p;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedPeriod = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _getPeriodLabel(p),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? _darkGreen : _textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // 2. FINANCIAL HEALTH SCORE CARD (56px Circular Gauge)
  // ===========================================================================
  Widget _buildHealthScoreCard(
    double healthScore,
    String healthText,
    double savingsRate,
  ) {
    String insightText;
    if (savingsRate >= 50) {
      insightText =
          "Savings rate is ${savingsRate.toStringAsFixed(0)}% above target";
    } else if (savingsRate > 0) {
      insightText =
          "Savings rate is ${savingsRate.toStringAsFixed(0)}% (target: 50%)";
    } else {
      insightText = "Expenses exceeded income this period";
    }

    final Color statusColor = healthScore >= 0.6
        ? _darkGreen
        : healthScore >= 0.4
        ? Colors.orange.shade800
        : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Financial Health Score Card",
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: _showHealthScoreExplanation,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: _textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // 56px Circular Gauge
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: healthScore.clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: _primaryGreen,
                      strokeWidth: 6.5,
                      strokeCap: StrokeCap.round,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "${(healthScore * 100).toInt()}%",
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Health Status",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          "${(healthScore * 100).toInt()}% - $healthText",
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check_circle_rounded,
                          color: statusColor,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Insight",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderGrey),
                      ),
                      child: Text(
                        insightText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. CASH FLOW OVERVIEW CARD
  // ===========================================================================
  Widget _buildCashFlowCard(double income, double expense, double savingsRate) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Cash Flow Overview Card",
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Total Income Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Total Income:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        income.toINR(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Total Expense Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC62828),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Total Expense:",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        expense.toINR(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (savingsRate / 100).clamp(0.0, 1.0),
              minHeight: 6.5,
              backgroundColor: _borderGrey,
              color: _darkGreen,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Savings rate",
                style: TextStyle(
                  fontSize: 12,
                  color: _textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "${savingsRate.toStringAsFixed(0)}%",
                style: const TextStyle(
                  fontSize: 12,
                  color: _textDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. SPENDING BY CATEGORY CARD (Ranked List with Visual Bars)
  // ===========================================================================
  Widget _buildSpendingByCategoryCard(
    Map<String, double> categoryTotals,
    double totalExpense,
  ) {
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Spending by Category Card",
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  "No category expenses recorded for this period.",
                  style: TextStyle(color: _textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length > 5 ? 5 : entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final e = entries[index];
                final share = totalExpense > 0 ? (e.value / totalExpense) : 0.0;
                final catColor = CategoryTheme.getColor(e.key);
                final catBg = CategoryTheme.getBgColor(e.key);
                final catIcon = CategoryTheme.getIcon(e.key);

                return Row(
                  children: [
                    SizedBox(
                      width: 16,
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: catBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(catIcon, color: catColor, size: 19),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.value.toINR(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: share.clamp(0.0, 1.0),
                          minHeight: 5.5,
                          backgroundColor: _borderGrey,
                          color: catColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 34,
                      child: Text(
                        "${(share * 100).toStringAsFixed(0)}%",
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. PAYMENT MODE SPLIT CARD
  // ===========================================================================
  Widget _buildPaymentModeSplitCard(double cashSpent, double onlineSpent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Payment Mode Split Card",
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: _textDark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Cash Tile
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _canvasBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Cash:",
                        style: TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cashSpent.toINR(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Online Tile
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _canvasBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Online:",
                        style: TextStyle(
                          fontSize: 12,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        onlineSpent.toINR(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
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

  // ===========================================================================
  // 6. FRIEND LEDGER SUMMARY (Preserves Friend Data)
  // ===========================================================================
  Widget _buildFriendLedgerCard(double friendGiven, double friendTaken) {
    final net = friendGiven - friendTaken;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Friend Ledger Summary",
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  letterSpacing: -0.2,
                ),
              ),
              Icon(Icons.handshake_outlined, size: 18, color: _primaryGreen),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "To Receive:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        friendGiven.toINR(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "To Give:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFC62828),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        friendTaken.toINR(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Net Settlement:",
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _textMuted,
                ),
              ),
              Text(
                "${net >= 0 ? '+' : '-'}${net.abs().toINR()}",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: net >= 0
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 7. ADVANCED VISUAL CHARTS TOGGLE
  // ===========================================================================
  Widget _buildAdvancedChartsToggle(
    Map<String, double> categoryTotals,
    double totalExpense,
    double income,
    double expense,
    double cashIn,
    double cashOut,
    double onlineIn,
    double onlineOut,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _showAdvancedCharts,
            onExpansionChanged: (v) => setState(() => _showAdvancedCharts = v),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: _primaryGreen,
                size: 20,
              ),
            ),
            title: const Text(
              "Visual Charts & Analysis",
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
            subtitle: const Text(
              "Interactive cashflow comparison & category donut chart",
              style: TextStyle(fontSize: 11.5, color: _textMuted),
            ),
            children: [
              const Divider(height: 1, color: _borderGrey),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCashflowBarChart(
                  income: income,
                  expense: expense,
                  cashIn: cashIn,
                  cashOut: cashOut,
                  onlineIn: onlineIn,
                  onlineOut: onlineOut,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCategoryDonutSection(categoryTotals, totalExpense),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashflowBarChart({
    required double income,
    required double expense,
    required double cashIn,
    required double cashOut,
    required double onlineIn,
    required double onlineOut,
  }) {
    final maxVal = [
      income,
      expense,
      cashIn.toDouble(),
      cashOut.toDouble(),
      onlineIn.toDouble(),
      onlineOut.toDouble(),
    ].reduce((a, b) => a > b ? a : b);
    final double maxY = maxVal > 0 ? maxVal * 1.25 : 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                "Cashflow Comparison",
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _legendDot(_primaryGreen, "Inflow"),
                const SizedBox(width: 10),
                _legendDot(const Color(0xFFEF5350), "Outflow"),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 170,
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
                            color: isIncome
                                ? Colors.greenAccent
                                : const Color(0xFFFF8A80),
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
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                            color: _textDark,
                          ),
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
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                _makeBarGroup(0, income, expense),
                _makeBarGroup(1, cashIn.toDouble(), cashOut.toDouble()),
                _makeBarGroup(2, onlineIn.toDouble(), onlineOut.toDouble()),
              ],
            ),
            duration: const Duration(milliseconds: 150),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _makeBarGroup(int x, double inVal, double outVal) {
    return BarChartGroupData(
      x: x,
      barsSpace: 6,
      barRods: [
        BarChartRodData(
          toY: inVal,
          color: _primaryGreen,
          width: 13,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
        BarChartRodData(
          toY: outVal,
          color: const Color(0xFFEF5350),
          width: 13,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
        ),
      ],
    );
  }

  Widget _buildCategoryDonutSection(
    Map<String, double> categoryTotals,
    double totalExpense,
  ) {
    if (categoryTotals.isEmpty) {
      return const Center(
        child: Text(
          "No category expenses for this period.",
          style: TextStyle(color: _textMuted, fontSize: 12),
        ),
      );
    }

    final entries = categoryTotals.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Expense Distribution Donut",
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 160,
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
                          _touchedPieIndex = pieTouchResponse
                              .touchedSection!
                              .touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2.5,
                    centerSpaceRadius: 36,
                    sections: List.generate(entries.length, (i) {
                      final isTouched = i == _touchedPieIndex;
                      final double fontSize = isTouched ? 12 : 9.5;
                      final double radius = isTouched ? 44 : 38;
                      final entry = entries[i];
                      final share = totalExpense > 0
                          ? (entry.value / totalExpense) * 100
                          : 0.0;
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
                  duration: const Duration(milliseconds: 150),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.take(4).map((e) {
                    final share = totalExpense > 0
                        ? (e.value / totalExpense) * 100
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: CategoryTheme.getColor(e.key),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${share.toStringAsFixed(0)}%",
                            style: const TextStyle(
                              fontSize: 11,
                              color: _textMuted,
                              fontWeight: FontWeight.bold,
                            ),
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
      ],
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
          style: const TextStyle(
            fontSize: 11.5,
            color: _textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 8. BOTTOM ACTION CTA BUTTON (52px Elevated Button)
  // ===========================================================================
  Widget _buildExportButton(VoidCallback onExport) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(
            Icons.download_rounded,
            color: Colors.white,
            size: 20,
          ),
          label: const Text(
            "Export PDF Report",
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          onPressed: onExport,
        ),
      ),
    );
  }
}
