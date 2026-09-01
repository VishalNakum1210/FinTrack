import 'package:FinTrack/GetInformation/session_manager.dart';
import 'package:FinTrack/providers/expense_provider.dart';
import 'package:FinTrack/providers/user_provider.dart';
import 'package:FinTrack/services/export_service.dart';
import 'package:FinTrack/user_pages/add_spent.dart';
import 'package:FinTrack/utils/date_helper.dart';
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
  String currentSort = "Newest First";
  final List<String> sortList = const ["Newest First", "Oldest First"];
  String selectedCategory = "All";
  static const Color green = Color(0xFF8BC24A);

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
    }
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

  String money(int value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, _) {
        final isLoading = expenseProvider.isLoading;
        List<Map<String, dynamic>> rawFiltered = expenseProvider.getFilteredRecords(selectedCategory);
        List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(rawFiltered);

        // Fast sort primarily by pre-parsed transaction Date, secondarily by timestamp
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

        final income = expenseProvider.totalIncome;
        final expense = expenseProvider.totalExpense;
        final spentCash = expenseProvider.spentCash;
        final spentOnline = expenseProvider.spentOnline;
        final recordCount = records.length;

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
                    records: records,
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
          body: isLoading
              ? const Center(child: CircularProgressIndicator(color: green))
              : (records.isEmpty)
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          children: [
                          _categoryChips(),
                          const SizedBox(height: 10),
                          _balanceCard(income, expense, spentCash, spentOnline, recordCount),
                          const SizedBox(height: 10),
                          const Expanded(
                            child: Center(
                              child: Text(
                                "No Record Found!",
                                style: TextStyle(color: green),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
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
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: records.length,
                            itemBuilder: (context, index) {
                              final item = records[index];
                              final date = (item["Date"] ?? "").toString();
                              final formattedCurrentDate = formatDate(date);
                              final formattedPrevDate = index > 0
                                  ? formatDate((records[index - 1]["Date"] ?? "").toString())
                                  : "";
                              final showHeader = index == 0 || formattedCurrentDate != formattedPrevDate;
                              final category = (item["Category"] ?? "Other").toString();
                              final desc = (item["Description"] ?? "").toString();
                              final method = (item["Payment_Mode"] ?? "").toString();
                              final amount = (double.tryParse(item["Amount"]?.toString() ?? '0') ?? 0.0).round();
                              final isIncome = ["Add CASH", "Add Online"].contains(method);

                              return InkWell(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showHeader && formattedCurrentDate.isNotEmpty)
                                      _sectionHeader('', formattedCurrentDate),
                                    _transactionTile(
                                      icon: iconName(category),
                                      iconColor: iconColor(category),
                                      bgColor: backgroundColor(category),
                                      title: category,
                                      subtitle: desc,
                                      method: method,
                                      time: date,
                                      amount: money(amount),
                                      isIncome: isIncome,
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text("Delete Record"),
                                      content: const Text(
                                        "Are you sure you want to delete this record?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            if (item["key"] != null) {
                                              await deleteRecord(item["key"]);
                                            }
                                          },
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
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
          _chip(iconName("Food"), 'Food', iconColor("Food")),
          _chip(iconName("Shopping"), 'Shopping', iconColor("Shopping")),
          _chip(iconName("Transport"), 'Transport', iconColor("Transport")),
          _chip(iconName("Education"), 'Education', iconColor("Education")),
          _chip(iconName("HealthCare"), 'HealthCare', iconColor("HealthCare")),
          _chip(
            iconName("Entertainment"),
            'Entertainment',
            iconColor("Entertainment"),
          ),
          _chip(iconName("Add Money"), 'Add Money', iconColor("Add Money")),
          _chip(Icons.more_horiz, 'Other', iconColor("other")),
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
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? backgroundColor(label) : Colors.white,
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
                    child: balanceItem(
                      Icons.trending_up_rounded,
                      Colors.greenAccent,
                      "Income",
                      money(income),
                    ),
                  ),

                  Container(height: 45, width: 1, color: Colors.white24),

                  Expanded(
                    child: balanceItem(
                      Icons.trending_down_rounded,
                      const Color(0xFFFF8A80),
                      "Expense",
                      money(expense),
                    ),
                  ),

                  Container(height: 45, width: 1, color: Colors.white24),

                  Expanded(
                    child: balanceItem(
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
                    child: balanceItem(
                      Icons.payments_rounded,
                      const Color(0xFFFFD180),
                      "Cash Exp.",
                      money(spentCash),
                    ),
                  ),

                  Container(height: 45, width: 1, color: Colors.white24),

                  Expanded(
                    child: balanceItem(
                      Icons.credit_card_rounded,
                      const Color(0xFF80D8FF),
                      "Online Exp.",
                      money(spentOnline),
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
                      method == 'Spent Cash'
                          ? Icons.currency_rupee_rounded
                          : method == 'Spent Online'
                          ? Icons.payment_rounded
                          // : method == 'Bank Transfer'
                          // ? Icons.account_balance
                          : Icons.add_card_rounded,
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

Widget balanceItem(
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

IconData iconName(String category) {
  switch (category) {
    case "Shopping":
      return Icons.shopping_bag_rounded;
    case "Food":
      return Icons.restaurant_rounded;
    case "Transport":
      return Icons.directions_car_filled_rounded;
    case "Education":
      return Icons.school_rounded;
    case "HealthCare":
      return Icons.medical_services_rounded;
    case "Entertainment":
      return Icons.movie_filter_rounded;
    case "Add Money":
      return Icons.account_balance_wallet_rounded;
    default:
      return Icons.category_rounded;
  }
}

Color iconColor(String category) {
  switch (category.trim()) {
    case "Shopping":
      return Colors.deepOrange; // Purple

    case "Food":
      return const Color(0xFFFF9800); // Orange

    case "Transport":
      return const Color(0xFF2196F3); // Blue

    case "Education":
      return const Color(0xFF3F51B5); // Indigo

    case "HealthCare":
      return const Color(0xFFE53935); // Red

    case "Entertainment":
      return const Color(0xFFEC407A); // Pink

    case "Add CASH":
    case "Add Online":
      return const Color(0xFF43A047); // Green

    default:
      return const Color(0xFF757575); // Grey
  }
}

Color backgroundColor(String category) {
  switch (category.trim()) {
    case "Shopping":
      return const Color.fromARGB(39, 255, 86, 34); // Light Purple

    case "Food":
      return const Color(0xFFFFF3E0); // Light Orange

    case "Transport":
      return const Color(0xFFE3F2FD); // Light Blue

    case "Education":
      return const Color(0xFFE8EAF6); // Light Indigo

    case "HealthCare":
      return const Color(0xFFFFEBEE); // Light Red

    case "Entertainment":
      return const Color(0xFFFCE4EC); // Light Pink

    case "Add CASH":
    case "Add Online":
      return const Color(0xFFE8F5E9); // Light Green

    default:
      return const Color(0xFFF5F5F5); // Light Grey
  }
}

IconData methodIcon(String method) {
  switch (method) {
    case "Spent Cash":
      return Icons.money_off_rounded;
    case "Spent Online":
      return Icons.payment_rounded;
    default:
      return Icons.add_card_rounded;
  }
}
