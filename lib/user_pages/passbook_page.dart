import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/user_pages/add_spent.dart';
import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:fin_track/widgets/confirm_dialog.dart';
import 'package:fin_track/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class PassbookApp extends StatefulWidget {
  const PassbookApp({super.key});

  @override
  State<PassbookApp> createState() => PassbookPageState();
}

class PassbookPageState extends State<PassbookApp> {
  String currentSort = "Newest First";
  final List<String> sortList = const ["Newest First", "Oldest First"];
  String selectedCategory = "All";
  static const Color green = CategoryTheme.primaryGreen;

  int _displayLimit = 50;
  List<Map<String, dynamic>> _cachedSorted = [];
  String _lastSortKey = '';
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (_displayLimit < _cachedSorted.length) {
          setState(() => _displayLimit += 50);
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool force = false}) async {
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (mounted && phone.isNotEmpty) {
      context.read<ExpenseProvider>().fetchExpenses(phone, force: force);
    }
  }

  void _showTransactionDetails(BuildContext context, Map<String, dynamic> item) {
    final category = (item["Category"] ?? "Other").toString();
    final desc = (item["Description"] ?? "No description").toString();
    final method = (item["Payment_Mode"] ?? "").toString();
    final amount = (double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0).round();
    final date = (item["Date"] ?? "").toString();
    final isIncome = ["Add CASH", "Add Online"].contains(method);
    final key = (item["key"] ?? "").toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
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
                CircleAvatar(
                  radius: 26,
                  backgroundColor: CategoryTheme.getBgColor(category),
                  child: Icon(CategoryTheme.getIcon(category), color: CategoryTheme.getColor(category), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(formatDate(date), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Text(
                  amount.toINR(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            if (desc.isNotEmpty) ...[
              const Text("Description", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
            ],
            const Text("Payment Mode", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(method, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text("Delete Transaction", style: TextStyle(fontWeight: FontWeight.bold)),
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
          ],
        ),
      ),
    );
  }

  String formatDate(String date) {
    return DateHelper.formatDisplay(date);
  }

  void changeOrder(String? value) {
    if (value != null && currentSort != value) {
      setState(() {
        currentSort = value;
      });
    }
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
    if (records.isEmpty) {
      Fluttertoast.showToast(msg: "No records to export");
      return;
    }

    final userProvider = context.read<UserProvider>();
    final userName = userProvider.name.isNotEmpty ? userProvider.name : "User";
    final phone = userProvider.phoneNumber;
    final expenseProv = context.read<ExpenseProvider>();
    final addCash = expenseProv.addCash;
    final addOnline = expenseProv.addOnline;
    final currentBalance = income - expense;

    Fluttertoast.showToast(msg: "Generating PDF Statement...");
    await ExportService.exportPassbookPdf(
      userName: userName,
      phoneNumber: phone,
      records: records,
      totalIncome: income,
      totalExpense: expense,
      currentBalance: currentBalance,
      addCash: addCash,
      spentCash: spentCash,
      addOnline: addOnline,
      spentOnline: spentOnline,
      filterCategory: selectedCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, _) {
        final isLoading = expenseProvider.isLoading;
        List<Map<String, dynamic>> rawFiltered = expenseProvider.getFilteredRecords(selectedCategory);
        
        final sortKey = '${expenseProvider.records.length}_${currentSort}_$selectedCategory';
        if (sortKey != _lastSortKey) {
          List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(rawFiltered);
          records.sort((a, b) {
            final DateTime? dateA = (a["_parsedDate"] as DateTime?) ?? DateHelper.parse(a["Date"]);
            final DateTime? dateB = (b["_parsedDate"] as DateTime?) ?? DateHelper.parse(b["Date"]);

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
          _cachedSorted = records;
          _lastSortKey = sortKey;
        }

        final displayedRecords = _cachedSorted.take(_displayLimit).toList();

        final income = expenseProvider.totalIncome;
        final expense = expenseProvider.totalExpense;
        final spentCash = expenseProvider.spentCash;
        final spentOnline = expenseProvider.spentOnline;
        final recordCount = _cachedSorted.length;

        return Scaffold(
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "PassBook Page",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: green,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
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
                icon: const Icon(Icons.picture_as_pdf, color: green),
                onPressed: () {
                  exportToPdf(
                    context: context,
                    records: _cachedSorted,
                    income: income,
                    expense: expense,
                    spentCash: spentCash,
                    spentOnline: spentOnline,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: green,
            shape: const CircleBorder(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddSpent()),
              );
            },
            child: const Icon(Icons.add, color: Colors.white, size: 34),
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
                      : (_cachedSorted.isEmpty)
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _categoryChips(),
                              const SizedBox(height: 10),
                              _balanceCard(income, expense, spentCash, spentOnline, recordCount),
                              const SizedBox(height: 80),
                              const Center(
                                child: Text(
                                  "No Record Found!",
                                  style: TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _categoryChips(),
                              const SizedBox(height: 10),
                              _balanceCard(income, expense, spentCash, spentOnline, recordCount),
                              const SizedBox(height: 10),
                              _sortRow(),
                              const SizedBox(height: 10),
                              if (displayedRecords.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(Icons.receipt_long_outlined, size: 50, color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        Text(
                                          "No transactions in $selectedCategory",
                                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayedRecords.length,
                                itemBuilder: (context, index) {
                                  final item = displayedRecords[index];
                                  final date = (item["Date"] ?? "").toString();
                                  final formattedCurrentDate = formatDate(date);
                                  final formattedPrevDate = index > 0
                                      ? formatDate((displayedRecords[index - 1]["Date"] ?? "").toString())
                                      : "";
                                  final showHeader = index == 0 || formattedCurrentDate != formattedPrevDate;
                                  final category = (item["Category"] ?? "Other").toString();
                                  final desc = (item["Description"] ?? "").toString();
                                  final method = (item["Payment_Mode"] ?? "").toString();
                                  final amount = (double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0).round();
                                  final isIncome = ["Add CASH", "Add Online"].contains(method);
                                  final itemKey = item["key"]?.toString() ?? "$index";

                                  return Dismissible(
                                    key: Key(itemKey),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade400,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(Icons.delete, color: Colors.white, size: 28),
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
                                    child: InkWell(
                                      onTap: () => _showTransactionDetails(context, item),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (showHeader && formattedCurrentDate.isNotEmpty)
                                            _sectionHeader('', formattedCurrentDate),
                                          _transactionTile(
                                            icon: CategoryTheme.getIcon(category),
                                            iconColor: CategoryTheme.getColor(category),
                                            bgColor: CategoryTheme.getBgColor(category),
                                            title: category,
                                            subtitle: desc,
                                            method: method,
                                            time: date,
                                            amount: amount.toINR(),
                                            isIncome: isIncome,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (_cachedSorted.length > _displayLimit)
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () => setState(() => _displayLimit += 50),
                                    icon: const Icon(Icons.expand_more, color: green),
                                    label: const Text(
                                      'Load More',
                                      style: TextStyle(color: green, fontWeight: FontWeight.w600),
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

  Widget _categoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(Icons.grid_view_rounded, 'All', green),
          _chip(CategoryTheme.getIcon("Food"), 'Food', CategoryTheme.getColor("Food")),
          _chip(CategoryTheme.getIcon("Shopping"), 'Shopping', CategoryTheme.getColor("Shopping")),
          _chip(CategoryTheme.getIcon("Transport"), 'Transport', CategoryTheme.getColor("Transport")),
          _chip(CategoryTheme.getIcon("Education"), 'Education', CategoryTheme.getColor("Education")),
          _chip(CategoryTheme.getIcon("HealthCare"), 'HealthCare', CategoryTheme.getColor("HealthCare")),
          _chip(CategoryTheme.getIcon("Entertainment"), 'Entertainment', CategoryTheme.getColor("Entertainment")),
          _chip(CategoryTheme.getIcon("Add Money"), 'Add Money', CategoryTheme.getColor("Add Money")),
          _chip(Icons.more_horiz, 'Other', CategoryTheme.getColor("other")),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color iconColor) {
    bool selected = selectedCategory == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = label;
          _displayLimit = 50;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? CategoryTheme.getBgColor(label) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? iconColor : const Color(0xFFE8E8E8),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 15),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(int income, int expense, int spentCash, int spentOnline, int recordCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8BC24A), Color(0xFF689F38), Color(0xFF33691E)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: .25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -40,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _balanceItem(
                      Icons.trending_up_rounded,
                      Colors.greenAccent,
                      "Income",
                      income.toINR(),
                    ),
                  ),
                  Container(height: 45, width: 1, color: Colors.white24),
                  Expanded(
                    child: _balanceItem(
                      Icons.trending_down_rounded,
                      const Color(0xFFFF8A80),
                      "Expense",
                      expense.toINR(),
                    ),
                  ),
                  Container(height: 45, width: 1, color: Colors.white24),
                  Expanded(
                    child: _balanceItem(
                      Icons.receipt_long_rounded,
                      Colors.white,
                      "Records",
                      recordCount,
                      isMoney: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _balanceItem(
                      Icons.payments_rounded,
                      const Color(0xFFFFD180),
                      "Cash Exp.",
                      spentCash.toINR(),
                    ),
                  ),
                  Container(height: 45, width: 1, color: Colors.white24),
                  Expanded(
                    child: _balanceItem(
                      Icons.credit_card_rounded,
                      const Color(0xFF80D8FF),
                      "Online Exp.",
                      spentOnline.toINR(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceItem(
    IconData icon,
    Color iconColor,
    String title,
    dynamic value, {
    bool isMoney = true,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            isMoney ? "$value" : value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sortRow() {
    return Row(
      children: [
        const Text(
          'Sort by:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              DropdownMenu<String>(
                initialSelection: currentSort,
                dropdownMenuEntries: sortList
                    .map((item) => DropdownMenuEntry(value: item, label: item))
                    .toList(),
                onSelected: (value) {
                  changeOrder(value);
                },
                inputDecorationTheme: InputDecorationTheme(
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      width: 3,
                      color: Color(0xFFE0E0E0),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      width: 3,
                      color: Color(0xFFE0E0E0),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          Text(
            date,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String method,
    required String time,
    required String amount,
    required bool isIncome,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      CategoryTheme.getMethodIcon(method),
                      color: Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        method,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            (["Add Online", "Add CASH"].contains(method))
                ? "+$amount"
                : "-$amount",
            style: TextStyle(
              color: isIncome ? green : Colors.red.shade700,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
