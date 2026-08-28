import 'package:FinTrack/GetInformation/SessionManager.dart';
import 'package:FinTrack/providers/expense_provider.dart';
import 'package:FinTrack/providers/friend_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SplitBillPage extends StatefulWidget {
  const SplitBillPage({super.key});

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  String selectedCategory = "Food";
  String selectedMode = "Spent Online";

  final List<String> categories = const [
    "Food",
    "Shopping",
    "Transport",
    "Education",
    "HealthCare",
    "Entertainment",
    "Other",
  ];

  final List<String> paymentModes = const [
    "Spent Online",
    "Spent Cash",
  ];

  // Selected friend phone numbers
  final Set<String> selectedFriendNumbers = {};
  bool isLoading = false;

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    amountController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriends();
    });
  }

  Future<void> _loadFriends() async {
    final phone = await SessionManager.getPhoneNumber() ?? "";
    if (phone.isNotEmpty && mounted) {
      context.read<FriendProvider>().fetchFriends(phone);
    }
  }

  @override
  void dispose() {
    amountController.removeListener(_onAmountChanged);
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(now) ? now : selectedDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> handleSplitBill() async {
    final rawAmount = amountController.text.trim();
    final description = descriptionController.text.trim();

    if (rawAmount.isEmpty || description.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill in amount and description");
      return;
    }

    final totalAmount = double.tryParse(rawAmount.replaceAll(',', '').trim());
    if (totalAmount == null || totalAmount <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid amount");
      return;
    }

    if (selectedFriendNumbers.isEmpty) {
      Fluttertoast.showToast(msg: "Please select at least 1 friend to split with");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final userPhone = await SessionManager.getPhoneNumber() ?? "";
      if (userPhone.isEmpty) {
        Fluttertoast.showToast(msg: "User session not found");
        return;
      }

      if (!mounted) return;

      final expenseProvider = context.read<ExpenseProvider>();
      final friendProvider = context.read<FriendProvider>();

      final totalPeople = selectedFriendNumbers.length + 1; // You + Selected Friends
      final sharePerPerson = ((totalAmount / totalPeople) * 100).round() / 100;
      final myShare = ((totalAmount - (sharePerPerson * selectedFriendNumbers.length)) * 100).round() / 100;
      final formattedDate = DateFormat('d/M/yyyy').format(selectedDate);

      final myShareStr = myShare.truncateToDouble() == myShare ? myShare.toInt().toString() : myShare.toStringAsFixed(2);
      final sharePerPersonStr = sharePerPerson.truncateToDouble() == sharePerPerson ? sharePerPerson.toInt().toString() : sharePerPerson.toStringAsFixed(2);
      final totalAmountStr = totalAmount.truncateToDouble() == totalAmount ? totalAmount.toInt().toString() : totalAmount.toStringAsFixed(2);

      // 1. Add Personal Expense (Your Share) into Passbook
      final passbookSuccess = await expenseProvider.addExpense(
        phoneNumber: userPhone,
        amount: myShareStr,
        description: "$description (Your 1/$totalPeople share of ₹$totalAmountStr)",
        paymentMode: selectedMode,
        date: formattedDate,
        category: selectedCategory,
      );

      // 2. Add each friend's share in an optimized batch
      final friendSuccessCount = await friendProvider.batchAddFriendTransactions(
        userPhone: userPhone,
        friendNumbers: selectedFriendNumbers.toList(),
        amountPerFriend: sharePerPersonStr,
        description: "Split: $description (Total ₹$totalAmountStr across $totalPeople people)",
        paymentMode: selectedMode,
        date: formattedDate,
        categoryType: "Give Money To Friend",
      );

      if (passbookSuccess) {
        Fluttertoast.showToast(
          msg: "Split Complete! Added ₹$myShareStr to your passbook & ₹$sharePerPersonStr to $friendSuccessCount friends' ledgers.",
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(msg: "Failed to record bill split");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error splitting bill: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(width: 1.5, color: Color(0xFF8BC24A)),
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(width: 2, color: Color(0xFF689F38)),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF8BC24A);
    final friendProvider = context.watch<FriendProvider>();
    final friends = friendProvider.friends;

    final totalAmount = double.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final totalPeople = selectedFriendNumbers.length + 1;
    final sharePerPerson = totalAmount > 0 ? ((totalAmount / totalPeople) * 100).round() / 100 : 0.0;
    final myShare = totalAmount > 0 ? ((totalAmount - (sharePerPerson * selectedFriendNumbers.length)) * 100).round() / 100 : 0.0;

    final myShareStr = myShare.truncateToDouble() == myShare ? myShare.toInt().toString() : myShare.toStringAsFixed(2);
    final sharePerPersonStr = sharePerPerson.truncateToDouble() == sharePerPerson ? sharePerPerson.toInt().toString() : sharePerPerson.toStringAsFixed(2);
    final totalAmountStr = totalAmount.truncateToDouble() == totalAmount ? totalAmount.toInt().toString() : totalAmount.toStringAsFixed(2);
    final totalCollectStr = (sharePerPerson * selectedFriendNumbers.length).truncateToDouble() == (sharePerPerson * selectedFriendNumbers.length)
        ? (sharePerPerson * selectedFriendNumbers.length).toInt().toString()
        : (sharePerPerson * selectedFriendNumbers.length).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF2),
      appBar: AppBar(
        title: const Text(
          "Split Bill with Friends",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8BC24A), Color(0xFF689F38)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: .25),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_work_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Multi-Friend Bill Splitter",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Your share goes to Passbook, and each friend's share goes into their ledger.",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 1. Bill Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "1. Bill Details",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF33691E)),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDeco("Total Bill Amount (₹)"),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: descriptionController,
                          decoration: _inputDeco("Bill Description (e.g. Dinner, Trip Taxi)"),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          readOnly: true,
                          decoration: _inputDeco("Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}").copyWith(
                            suffixIcon: const Icon(Icons.calendar_month_rounded, color: primary),
                          ),
                          onTap: pickDate,
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedCategory,
                                decoration: _inputDeco("Category").copyWith(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: categories
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedCategory = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedMode,
                                decoration: _inputDeco("Payment").copyWith(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: paymentModes
                                    .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => selectedMode = val);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Select Friends Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "2. Select Friends to Split With",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF33691E)),
                            ),
                            if (friends.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    if (selectedFriendNumbers.length == friends.length) {
                                      selectedFriendNumbers.clear();
                                    } else {
                                      selectedFriendNumbers.addAll(
                                        friends.map((f) => (f["friend_number"] ?? "").toString()),
                                      );
                                    }
                                  });
                                },
                                child: Text(
                                  selectedFriendNumbers.length == friends.length ? "Deselect All" : "Select All",
                                  style: const TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (friends.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                "No friends added yet. Please add friends in the Friend Ledger tab.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: friends.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final friend = friends[index];
                              final name = (friend["friend_name"] ?? "Friend").toString();
                              final number = (friend["friend_number"] ?? "").toString();
                              final isSelected = selectedFriendNumbers.contains(number);

                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: primary,
                                contentPadding: EdgeInsets.zero,
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                                subtitle: Text(number, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                secondary: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected ? primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: isSelected ? primary : Colors.grey.shade600,
                                    size: 18,
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedFriendNumbers.add(number);
                                    } else {
                                      selectedFriendNumbers.remove(number);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Live Breakdown Summary Card
                  if (totalAmount > 0 && selectedFriendNumbers.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F8E9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primary.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Live Split Calculation",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2E7D32)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "$totalPeople People Split",
                                  style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("🧾 Your Personal Share (Passbook):", style: TextStyle(fontSize: 13)),
                              Text(
                                "₹$myShareStr",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "👥 Each Friend Owes (${selectedFriendNumbers.length} friends):",
                                style: const TextStyle(fontSize: 13),
                              ),
                              Text(
                                "₹$sharePerPersonStr",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("💰 Total You Will Collect:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text(
                                "₹$totalCollectStr",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0), fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Confirm Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : handleSplitBill,
                      icon: const Icon(Icons.call_split_rounded, color: Colors.white),
                      label: Text(
                        "Split ₹$totalAmountStr with $totalPeople People",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: primary),
              ),
            ),
        ],
      ),
    );
  }
}
