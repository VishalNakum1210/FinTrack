import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/utils/category_theme.dart';
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

  void _addToAmount(double delta) {
    final current = double.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final newVal = current + delta;
    final str = newVal.truncateToDouble() == newVal ? newVal.toInt().toString() : newVal.toStringAsFixed(2);
    amountController.text = str;
    amountController.selection = TextSelection.fromPosition(TextPosition(offset: str.length));
  }

  void _clearAmount() {
    amountController.clear();
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

    final totalPeople = selectedFriendNumbers.length + 1; // You + Selected Friends
    final sharePerPerson = ((totalAmount / totalPeople) * 100).round() / 100;
    final myShare = ((totalAmount - (sharePerPerson * selectedFriendNumbers.length)) * 100).round() / 100;
    final formattedDate = DateFormat('d/M/yyyy').format(selectedDate);

    final myShareStr = myShare.truncateToDouble() == myShare ? myShare.toInt().toString() : myShare.toStringAsFixed(2);
    final sharePerPersonStr = sharePerPerson.truncateToDouble() == sharePerPerson ? sharePerPerson.toInt().toString() : sharePerPerson.toStringAsFixed(2);
    final totalAmountStr = totalAmount.truncateToDouble() == totalAmount ? totalAmount.toInt().toString() : totalAmount.toStringAsFixed(2);

    // Confirmation BottomSheet before proceeding
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Confirm Bill Split",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 14),
            Text("Total Bill: ₹$totalAmountStr", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text("Your Share: ₹$myShareStr (to Passbook)", style: const TextStyle(fontSize: 14, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text("Each Friend: ₹$sharePerPersonStr (${selectedFriendNumbers.length} friends)", style: const TextStyle(fontSize: 14, color: Color(0xFFE65100), fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8BC24A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Confirm & Split", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

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

      // 1. Add Personal Expense (Your Share) into Passbook
      final passbookSuccess = await expenseProvider.addExpense(
        phoneNumber: userPhone,
        amount: myShareStr,
        description: "$description (Your 1/$totalPeople share of ₹$totalAmountStr)",
        paymentMode: selectedMode,
        date: formattedDate,
        category: selectedCategory,
      );

      // 2. Add each friend's share in an atomic multi-path update
      final friendSuccess = await friendProvider.atomicMultiFriendSplit(
        userPhone: userPhone,
        friendNumbers: selectedFriendNumbers.toList(),
        amountPerFriend: sharePerPersonStr,
        description: "Split: $description (Total ₹$totalAmountStr across $totalPeople people)",
        paymentMode: selectedMode,
        date: formattedDate,
        categoryType: "Give Money To Friend",
      );

      if (passbookSuccess && friendSuccess) {
        Fluttertoast.showToast(
          msg: "Split Complete! Added ₹$myShareStr to your passbook & ₹$sharePerPersonStr to friends' ledgers.",
        );
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        // Keep page open on failure so user can retry
        Fluttertoast.showToast(msg: "Failed to record bill split. Please retry.");
      }
    } catch (e) {
      // Keep page open on error so user can retry
      Fluttertoast.showToast(msg: "Error splitting bill: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Split Bill",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Total Bill Card with Quick Add Chips
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
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
                              "TOTAL BILL AMOUNT",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            if (amountController.text.isNotEmpty)
                              GestureDetector(
                                onTap: _clearAmount,
                                child: Text(
                                  "Clear",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade400,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              "₹",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                maxLength: 10,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "0.00",
                                  hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                                  border: InputBorder.none,
                                  counterText: "",
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _quickAddChip("+100", () => _addToAmount(100)),
                              _quickAddChip("+500", () => _addToAmount(500)),
                              _quickAddChip("+1,000", () => _addToAmount(1000)),
                              _quickAddChip("+2,000", () => _addToAmount(2000)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Bill Meta (Description, Date, Category, Payment)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Bill Information",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          maxLength: 150,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: "Enter bill title (e.g. Dinner, Movie, Uber)",
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                            prefixIcon: const Icon(Icons.receipt_long_rounded, color: primary, size: 22),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            counterText: "",
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: primary, width: 1.8),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, color: primary, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('dd MMMM yyyy').format(selectedDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  "Change",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: selectedCategory,
                                    icon: const Icon(Icons.arrow_drop_down_rounded, color: primary),
                                    items: categories.map((c) {
                                      return DropdownMenuItem(
                                        value: c,
                                        child: Row(
                                          children: [
                                            Icon(CategoryTheme.getIcon(c), size: 16, color: CategoryTheme.getColor(c)),
                                            const SizedBox(width: 6),
                                            Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => selectedCategory = val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: selectedMode,
                                    icon: const Icon(Icons.arrow_drop_down_rounded, color: primary),
                                    items: paymentModes.map((m) {
                                      final isOnline = m.contains("Online");
                                      return DropdownMenuItem(
                                        value: m,
                                        child: Row(
                                          children: [
                                            Icon(isOnline ? Icons.credit_card_rounded : Icons.payments_rounded, size: 16, color: primary),
                                            const SizedBox(width: 6),
                                            Text(isOnline ? "Online" : "Cash", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => selectedMode = val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Select Friends to Split With
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
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
                            const Flexible(
                              child: Text(
                                "Select Friends to Split",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            if (friends.isNotEmpty)
                              InkWell(
                                onTap: () {
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
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F8E9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    selectedFriendNumbers.length == friends.length ? "Deselect All" : "Select All",
                                    style: const TextStyle(
                                      color: Color(0xFF558B2F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

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

                              return Material(
                                color: Colors.transparent,
                                child: CheckboxListTile(
                                  value: isSelected,
                                  activeColor: primary,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  subtitle: Text(number, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                  secondary: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSelected ? primary.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'F',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isSelected ? primary : const Color(0xFF64748B),
                                      ),
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
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. Dynamic Split Calculation Card
                  if (totalAmount > 0 && selectedFriendNumbers.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FEE7),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: primary.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
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
                                "Live Calculation",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "$totalPeople People",
                                  style: const TextStyle(
                                    color: Color(0xFF33691E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                "₹$sharePerPersonStr / person",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("🧾 Your Personal Share (Passbook):", style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                              Text(
                                "₹$myShareStr",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 13.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "👥 Friends Will Owe (${selectedFriendNumbers.length} friends):",
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                              ),
                              Text(
                                "₹$totalCollectStr",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100), fontSize: 13.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 5. Confirm & Record Split Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: (isLoading || totalAmount <= 0 || selectedFriendNumbers.isEmpty) ? null : handleSplitBill,
                      icon: const Icon(Icons.call_split_rounded, color: Colors.white, size: 20),
                      label: Text(
                        totalAmount > 0 && selectedFriendNumbers.isNotEmpty
                            ? "Confirm Split (₹$totalAmountStr • ₹$sharePerPersonStr/person)"
                            : "Select Friends & Enter Bill",
                        style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickAddChip(String label, VoidCallback onTap) {
    const Color primary = Color(0xFF8BC24A);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8E9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF558B2F),
            ),
          ),
        ),
      ),
    );
  }
}
