import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/user_pages/add_spent.dart';
import 'package:fin_track/utils/balance_helper.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:fin_track/widgets/confirm_dialog.dart';
import 'package:fin_track/widgets/dual_flow_card.dart';
import 'package:fin_track/widgets/edit_expense_modal.dart';
import 'package:fin_track/widgets/error_retry_widget.dart';
import 'package:fin_track/widgets/export_statement_modal.dart';
import 'package:fin_track/widgets/month_carousel.dart';
import 'package:fin_track/widgets/passbook_transaction_tile.dart';
import 'package:fin_track/widgets/smart_insight_banner.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PassbookApp extends StatefulWidget {
  const PassbookApp({super.key});

  @override
  State<PassbookApp> createState() => PassbookPageState();
}

class PassbookPageState extends State<PassbookApp> {
  static const Color green = CategoryTheme.primaryGreen;

  // Sorting & Filtering
  String currentSort = "Newest First";
  final List<String> sortList = const [
    "Newest First",
    "Oldest First",
    "Highest Amount",
    "Lowest Amount",
  ];
  String selectedCategory = "All";
  DateTime? selectedMonth;
  DateTimeRange? customDateRange;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Pagination & Display
  int _displayLimit = 50;
  List<Map<String, dynamic>> _cachedSorted = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (_displayLimit < _cachedSorted.length) {
          setState(() => _displayLimit += 50);
        }
      }
    });

    _searchController.addListener(() {
      final q = _searchController.text.trim().toLowerCase();
      if (q != _searchQuery) {
        setState(() {
          _searchQuery = q;
          _displayLimit = 50;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool force = false}) async {
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (mounted && phone.isNotEmpty) {
      context.read<ExpenseProvider>().fetchExpenses(phone, force: force);
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: green,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        customDateRange = picked;
        selectedMonth = null;
        _displayLimit = 50;
      });
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
    final runningBal = item["_runningBalance"] as double?;
    final splitFriend = item["splitFriend"]?.toString();

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Payment Mode",
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        method,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                if (runningBal != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Balance After",
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          runningBal.toINR(),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (splitFriend != null && splitFriend.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.group_outlined, size: 16, color: Color(0xFF6D28D9)),
                    const SizedBox(width: 6),
                    Text(
                      "Shared transaction with $splitFriend",
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6D28D9)),
                    ),
                  ],
                ),
              ),
            ],
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
                          await deleteRecord(key);
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

  Future<void> deleteRecord(String key) async {
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (mounted && phone.isNotEmpty) {
      await context.read<ExpenseProvider>().deleteExpense(
            phoneNumber: phone,
            key: key,
          );
    }
  }

  Future<void> exportToPdf({
    required BuildContext context,
    required List<Map<String, dynamic>> records,
    required int income,
    required int expense,
    required int spentCash,
    required int spentOnline,
  }) async {
    final userProvider = context.read<UserProvider>();
    final userName = userProvider.name.isNotEmpty ? userProvider.name : "User";
    final phone = userProvider.phoneNumber;

    if (records.isEmpty) {
      Fluttertoast.showToast(msg: "No records to export");
      return;
    }

    await showExportStatementModal(
      context: context,
      userName: userName,
      phoneNumber: phone,
      records: records,
      initialCategory: selectedCategory,
      initialDateRange: customDateRange,
    );
  }

  /// Calculates a 7-day spending activity array for the sparkline chart.
  List<double> _calculateWeeklySparks(List<Map<String, dynamic>> records) {
    final now = DateTime.now();
    final sparks = List<double>.filled(7, 0.0);
    for (final item in records) {
      final method = (item["Payment_Mode"] ?? "").toString();
      final isIncome = ["Add CASH", "Add Online"].contains(method);
      if (isIncome) continue;

      final dt = (item["_parsedDate"] as DateTime?) ?? DateHelper.parse(item["Date"]);
      if (dt != null) {
        final diffDays = now.difference(dt).inDays;
        if (diffDays >= 0 && diffDays < 7) {
          final amt = double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0;
          sparks[6 - diffDays] += amt;
        }
      }
    }
    return sparks;
  }

  /// Generates a contextual insight message based on active records.
  String _generateSmartInsight(double inflow, double outflow, List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return "Track your daily expenses to see automatic spending insights.";
    }

    if (inflow > outflow && outflow > 0) {
      final ratio = (((inflow - outflow) / inflow) * 100).round();
      return "💡 Great financial health! You have saved $ratio% of your inflow this period.";
    } else if (outflow > inflow && inflow > 0) {
      return "⚠️ Outflow exceeds inflow by ${(outflow - inflow).toINR()}. Review your non-essential expenses.";
    }

    // Top category spending insight
    final catTotals = <String, double>{};
    for (final r in records) {
      final method = (r["Payment_Mode"] ?? "").toString();
      if (["Add CASH", "Add Online"].contains(method)) continue;
      final cat = (r["Category"] ?? "Other").toString();
      final amt = double.tryParse(r["Amount"]?.toString() ?? '0') ?? 0.0;
      catTotals[cat] = (catTotals[cat] ?? 0.0) + amt;
    }

    if (catTotals.isNotEmpty) {
      final topCat = catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
      return "💡 Highest spending category: ${topCat.key} (${topCat.value.toINR()}).";
    }

    return "💡 Total of ${records.length} transactions recorded in this period.";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, _) {
        final isLoading = expenseProvider.isLoading;
        List<Map<String, dynamic>> rawRecords = expenseProvider.records;

        // 1. Calculate running balances chronologically across all user records (L3 DRY fix)
        final chronologicalRecords = BalanceHelper.computeRunningBalances(rawRecords);

        // 2. Filter by Category
        List<Map<String, dynamic>> filtered = chronologicalRecords.where((item) {
          if (selectedCategory == "All") return true;
          if (selectedCategory == "Expenses") {
            final method = (item["Payment_Mode"] ?? "").toString();
            return !["Add CASH", "Add Online"].contains(method);
          }
          if (selectedCategory == "Income") {
            final method = (item["Payment_Mode"] ?? "").toString();
            return ["Add CASH", "Add Online"].contains(method);
          }
          return (item["Category"] ?? "").toString().toLowerCase() ==
              selectedCategory.toLowerCase();
        }).toList();

        // 3. Filter by Month or Custom Date Range
        if (selectedMonth != null) {
          filtered = filtered.where((item) {
            final dt = (item["_parsedDate"] as DateTime?) ?? DateHelper.parse(item["Date"]);
            if (dt == null) return false;
            return dt.year == selectedMonth!.year && dt.month == selectedMonth!.month;
          }).toList();
        } else if (customDateRange != null) {
          filtered = filtered.where((item) {
            final dt = (item["_parsedDate"] as DateTime?) ?? DateHelper.parse(item["Date"]);
            if (dt == null) return false;
            return !dt.isBefore(customDateRange!.start) &&
                !dt.isAfter(customDateRange!.end.add(const Duration(days: 1)));
          }).toList();
        }

        // 4. Filter by Search Query
        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((item) {
            final cat = (item["Category"] ?? "").toString().toLowerCase();
            final desc = (item["Description"] ?? "").toString().toLowerCase();
            final method = (item["Payment_Mode"] ?? "").toString().toLowerCase();
            final amt = (item["Amount"] ?? "").toString();
            final dt = (item["Date"] ?? "").toString().toLowerCase();
            return cat.contains(_searchQuery) ||
                desc.contains(_searchQuery) ||
                method.contains(_searchQuery) ||
                amt.contains(_searchQuery) ||
                dt.contains(_searchQuery);
          }).toList();
        }

        // 5. Sort Records
        filtered.sort((a, b) {
          final DateTime? dateA = (a["_parsedDate"] as DateTime?) ?? DateHelper.parse(a["Date"]);
          final DateTime? dateB = (b["_parsedDate"] as DateTime?) ?? DateHelper.parse(b["Date"]);
          final amtA = double.tryParse(a["Amount"]?.toString() ?? '0') ?? 0.0;
          final amtB = double.tryParse(b["Amount"]?.toString() ?? '0') ?? 0.0;

          if (currentSort == "Highest Amount") {
            return amtB.compareTo(amtA);
          } else if (currentSort == "Lowest Amount") {
            return amtA.compareTo(amtB);
          }

          int cmp = 0;
          if (dateA != null && dateB != null) {
            cmp = currentSort == "Oldest First"
                ? dateA.compareTo(dateB)
                : dateB.compareTo(dateA);
          } else if (dateA != null) {
            cmp = -1;
          } else if (dateB != null) {
            cmp = 1;
          }

          if (cmp != 0) return cmp;

          final tA = (a["timestamp"] as num?)?.toInt() ?? 0;
          final tB = (b["timestamp"] as num?)?.toInt() ?? 0;
          return currentSort == "Oldest First"
              ? tA.compareTo(tB)
              : tB.compareTo(tA);
        });
        _cachedSorted = filtered;

        final displayedRecords = _cachedSorted.take(_displayLimit).toList();

        // Calculate inflow, outflow, and net saved for the current view
        double viewInflow = 0.0;
        double viewOutflow = 0.0;
        int viewSpentCash = 0;
        int viewSpentOnline = 0;

        for (final item in _cachedSorted) {
          final method = (item["Payment_Mode"] ?? "").toString();
          final isIncome = ["Add CASH", "Add Online"].contains(method);
          final amt = double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0;
          if (isIncome) {
            viewInflow += amt;
          } else {
            viewOutflow += amt;
            if (method.toLowerCase().contains("cash")) {
              viewSpentCash += amt.round();
            } else {
              viewSpentOnline += amt.round();
            }
          }
        }
        final viewNetSaved = viewInflow - viewOutflow;
        final weeklySparks = _calculateWeeklySparks(_cachedSorted);
        final insightMessage = _generateSmartInsight(viewInflow, viewOutflow, _cachedSorted);

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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Passbook & Statement",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w800,
                          fontSize: 17.5,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        "Real-time ledger & transaction history",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: "Export PDF Statement",
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: green, size: 20),
                ),
                onPressed: () {
                  exportToPdf(
                    context: context,
                    records: _cachedSorted,
                    income: viewInflow.round(),
                    expense: viewOutflow.round(),
                    spentCash: viewSpentCash,
                    spentOnline: viewSpentOnline,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: "passbook_fab",
            backgroundColor: green,
            elevation: 4,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddSpent()),
              );
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            label: const Text(
              "Add Entry",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          body: (isLoading && _cachedSorted.isEmpty)
              ? const Center(child: CircularProgressIndicator(color: green))
              : RefreshIndicator(
                  color: green,
                  onRefresh: () => _loadData(force: true),
                  child: (expenseProvider.hasError && _cachedSorted.isEmpty)
                      ? ErrorRetryWidget(
                          message: expenseProvider.errorMessage,
                          primaryColor: green,
                          onRetry: () => _loadData(force: true),
                        )
                      : SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Month & Calendar Carousel
                              MonthCarousel(
                                selectedMonth: selectedMonth,
                                onMonthSelected: (month) {
                                  setState(() {
                                    selectedMonth = month;
                                    customDateRange = null;
                                    _displayLimit = 50;
                                  });
                                },
                                onCustomDateRange: _pickCustomDateRange,
                              ),
                              if (customDateRange != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "Filter: ${DateFormat('d MMM').format(customDateRange!.start)} - ${DateFormat('d MMM yyyy').format(customDateRange!.end)}",
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => setState(() => customDateRange = null),
                                      child: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 14),

                              // 2. Dual-Flow Cashflow & Savings Card
                              DualFlowCard(
                                totalInflow: viewInflow,
                                totalOutflow: viewOutflow,
                                netSaved: viewNetSaved,
                                weeklySparks: weeklySparks,
                                title: selectedMonth != null
                                    ? "${DateFormat('MMMM yyyy').format(selectedMonth!)} Net Saved:"
                                    : "Total Net Saved:",
                                subtitle: "Mini 7-day spending activity",
                              ),
                              const SizedBox(height: 12),

                              // 3. Smart Insight Banner
                              SmartInsightBanner(message: insightMessage),
                              const SizedBox(height: 14),

                              // 4. Search Bar Dock
                              _buildSearchDock(),
                              const SizedBox(height: 10),

                              // 5. Category Chips Row
                              _buildCategoryChips(),
                              const SizedBox(height: 12),

                              // 6. Sort & Count Row
                              _buildSortAndCountRow(_cachedSorted.length),
                              const SizedBox(height: 12),

                              // 7. Transactions List with Date Headers & Running Balances
                              if (displayedRecords.isEmpty)
                                _buildEmptyState()
                              else
                                _buildTransactionsList(displayedRecords),

                              // 8. Pagination Load More Button
                              if (_cachedSorted.length > _displayLimit)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Center(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: green, width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                      onPressed: () => setState(() => _displayLimit += 50),
                                      icon: const Icon(Icons.expand_more_rounded, color: green),
                                      label: Text(
                                        "Load More (${_cachedSorted.length - _displayLimit} remaining)",
                                        style: const TextStyle(
                                          color: green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
        );
      },
    );
  }

  Widget _buildSearchDock() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: "Search merchant, note, amount, mode...",
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final chips = [
      {'label': 'All', 'icon': Icons.grid_view_rounded, 'color': green},
      {'label': 'Expenses', 'icon': Icons.arrow_upward_rounded, 'color': const Color(0xFFC62828)},
      {'label': 'Income', 'icon': Icons.arrow_downward_rounded, 'color': const Color(0xFF2E7D32)},
      {'label': 'Food', 'icon': CategoryTheme.getIcon("Food"), 'color': CategoryTheme.getColor("Food")},
      {'label': 'Shopping', 'icon': CategoryTheme.getIcon("Shopping"), 'color': CategoryTheme.getColor("Shopping")},
      {'label': 'Transport', 'icon': CategoryTheme.getIcon("Transport"), 'color': CategoryTheme.getColor("Transport")},
      {'label': 'Bills', 'icon': Icons.receipt_outlined, 'color': const Color(0xFF0288D1)},
      {'label': 'Education', 'icon': CategoryTheme.getIcon("Education"), 'color': CategoryTheme.getColor("Education")},
      {'label': 'HealthCare', 'icon': CategoryTheme.getIcon("HealthCare"), 'color': CategoryTheme.getColor("HealthCare")},
      {'label': 'Entertainment', 'icon': CategoryTheme.getIcon("Entertainment"), 'color': CategoryTheme.getColor("Entertainment")},
      {'label': 'Other', 'icon': Icons.more_horiz_rounded, 'color': CategoryTheme.getColor("other")},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: chips.map((chip) {
          final label = chip['label'] as String;
          final icon = chip['icon'] as IconData;
          final color = chip['color'] as Color;
          final isSelected = selectedCategory.toLowerCase() == label.toLowerCase();

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = label;
                _displayLimit = 50;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(icon, color: isSelected ? Colors.white : color, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortAndCountRow(int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            "Showing $totalCount ${totalCount == 1 ? 'entry' : 'entries'}",
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentSort,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF475569)),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              items: sortList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) {
                if (val != null && val != currentSort) {
                  setState(() => currentSort = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            const Text(
              "No Transactions Found",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _searchQuery.isNotEmpty
                  ? "No results matching '$_searchQuery'"
                  : "No records found for the selected filter.",
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(List<Map<String, dynamic>> records) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final item = records[index];
        final rawDate = (item["Date"] ?? "").toString();
        final dt = (item["_parsedDate"] as DateTime?) ?? DateHelper.parse(rawDate);
        final formattedCurrentDate = dt != null ? DateHelper.formatDisplay(dt) : rawDate;

        final prevItem = index > 0 ? records[index - 1] : null;
        final prevDt = prevItem != null
            ? ((prevItem["_parsedDate"] as DateTime?) ?? DateHelper.parse(prevItem["Date"]))
            : null;
        final formattedPrevDate = prevDt != null ? DateHelper.formatDisplay(prevDt) : "";

        final showHeader = index == 0 || formattedCurrentDate != formattedPrevDate;

        // Compute net day total for the header
        double dayNet = 0.0;
        int dayCount = 0;
        if (showHeader && dt != null) {
          for (int i = index; i < records.length; i++) {
            final checkDt = (records[i]["_parsedDate"] as DateTime?) ?? DateHelper.parse(records[i]["Date"]);
            if (checkDt != null &&
                checkDt.year == dt.year &&
                checkDt.month == dt.month &&
                checkDt.day == dt.day) {
              dayCount++;
              final amt = double.tryParse(records[i]["Amount"]?.toString() ?? '0') ?? 0.0;
              final m = (records[i]["Payment_Mode"] ?? "").toString();
              if (["Add CASH", "Add Online"].contains(m)) {
                dayNet += amt;
              } else {
                dayNet -= amt;
              }
            } else {
              break;
            }
          }
        }

        final category = (item["Category"] ?? "Other").toString();
        final desc = (item["Description"] ?? "").toString();
        final method = (item["Payment_Mode"] ?? "").toString();
        final amount = double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0;
        final isIncome = ["Add CASH", "Add Online"].contains(method);
        final itemKey = item["key"]?.toString() ?? "$index";
        final runningBal = item["_runningBalance"] as double?;
        final splitFriend = item["splitFriend"]?.toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              _buildTimelineDateHeader(
                date: dt,
                fallbackDate: formattedCurrentDate,
                count: dayCount,
                dayNet: dayNet,
              ),
            Dismissible(
              key: Key(itemKey),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
              ),
              confirmDismiss: (_) async {
                return await showDeleteConfirmDialog(
                  context,
                  title: "Delete Record",
                  message: "Are you sure you want to delete this record?",
                );
              },
              onDismissed: (_) async {
                if (itemKey.isNotEmpty) {
                  await deleteRecord(itemKey);
                }
              },
              child: PassbookTransactionTile(
                category: category,
                description: desc,
                paymentMode: method,
                time: DateHelper.formatDisplay(rawDate),
                amount: amount,
                isIncome: isIncome,
                runningBalance: (selectedCategory == "All" && _searchQuery.isEmpty) ? runningBal : null,
                splitFriendName: splitFriend,
                onTap: () => _showTransactionDetails(context, item),
                onEdit: () async {
                  final result = await showEditExpenseModal(context: context, record: item);
                  if (result == true && mounted) {
                    setState(() {});
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineDateHeader({
    required DateTime? date,
    required String fallbackDate,
    required int count,
    required double dayNet,
  }) {
    String headerText = fallbackDate;
    if (date != null) {
      final now = DateTime.now();
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final yesterday = now.subtract(const Duration(days: 1));
      final isYesterday = date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;

      final dayLabel = isToday
          ? "TODAY"
          : isYesterday
              ? "YESTERDAY"
              : DateFormat('d MMM yyyy').format(date).toUpperCase();

      final countLabel = count == 1 ? "1 Transaction" : "$count Transactions";
      final netLabel = dayNet >= 0 ? "Net +${dayNet.toINR()}" : "Net -${dayNet.abs().toINR()}";

      headerText = "$dayLabel • $countLabel • $netLabel";
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8, left: 4),
      child: Text(
        headerText,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
