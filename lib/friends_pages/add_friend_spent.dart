import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AddFriendExpenses extends StatefulWidget {
  final String friendNumber;
  const AddFriendExpenses({
    super.key,
    required this.friendNumber,
  });

  @override
  State<AddFriendExpenses> createState() => _AddFriendExpensesState();
}

class _AddFriendExpensesState extends State<AddFriendExpenses> {
  bool isLoading = false;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  final List<String> paymentModes = const [
    "Spent Online",
    "Spent Cash",
  ];

  final List<String> categoryTypes = const [
    "Give Money To Friend",
    "Take Money From Friend",
  ];

  late String selectedMode;
  late String selectedType;

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
    selectedMode = paymentModes.first;
    selectedType = categoryTypes.first;

    amountController.addListener(_onAmountChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final friends = context.read<FriendProvider>().friends;
      final exists = friends.any((f) => (f["friend_number"] ?? "").toString() == widget.friendNumber);
      if (!exists && friends.isNotEmpty) {
        Fluttertoast.showToast(msg: "Notice: Friend not found in recent friend list");
      }
    });
  }

  @override
  void dispose() {
    amountController.removeListener(_onAmountChanged);
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> getAllDetails() async {
    String amount = amountController.text.trim();
    String description = descriptionController.text.trim();

    if (amount.isEmpty || description.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill in all fields");
      return;
    }

    final parsed = double.tryParse(amount.replaceAll(',', '').trim());
    if (parsed == null || parsed <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid amount");
      return;
    }
    final formattedAmount = parsed.truncateToDouble() == parsed ? parsed.toInt().toString() : parsed.toStringAsFixed(2);

    setState(() {
      isLoading = true;
    });

    try {
      String userPhoneNumber = await SessionManager.getPhoneNumber() ?? "";
      if (userPhoneNumber.isEmpty) {
        Fluttertoast.showToast(msg: "User session not found");
        return;
      }

      String formattedDate = DateFormat('d/M/yyyy').format(selectedDate);
      if (!mounted) return;
      final success = await context.read<FriendProvider>().addFriendTransaction(
        userPhone: userPhoneNumber,
        friendNumber: widget.friendNumber,
        amount: formattedAmount,
        description: description,
        paymentMode: selectedMode,
        date: formattedDate,
        categoryType: selectedType,
      );

      if (success) {
        Fluttertoast.showToast(msg: "Friend expense recorded successfully");
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(msg: "Failed to save expense");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save expense: $e");
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
    final friends = context.watch<FriendProvider>().friends;
    final friendData = friends.firstWhere(
      (f) => (f["friend_number"] ?? "").toString() == widget.friendNumber,
      orElse: () => {"friend_name": "Friend", "friend_number": widget.friendNumber},
    );
    final friendName = (friendData["friend_name"] ?? "Friend").toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Record Friend Expense",
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
                  // 1. Friend Info Header Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: primary.withValues(alpha: 0.15),
                          child: Text(
                            friendName.isNotEmpty ? friendName[0].toUpperCase() : 'F',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friendName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.friendNumber,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Ledger Entry",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF558B2F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Hero Amount Card with Quick Add Chips
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
                              "TRANSACTION AMOUNT",
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

                  // 3. Direction / Transaction Type Selector
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
                          "Transaction Type",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // You Gave Money
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => selectedType = "Give Money To Friend"),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: selectedType == "Give Money To Friend"
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selectedType == "Give Money To Friend"
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFE2E8F0),
                                      width: selectedType == "Give Money To Friend" ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: selectedType == "Give Money To Friend"
                                              ? const Color(0xFF2E7D32).withValues(alpha: 0.2)
                                              : Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_upward_rounded,
                                          size: 20,
                                          color: selectedType == "Give Money To Friend"
                                              ? const Color(0xFF2E7D32)
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "You Gave",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: selectedType == "Give Money To Friend"
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Friend owes you",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: selectedType == "Give Money To Friend"
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // You Took Money
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => selectedType = "Take Money From Friend"),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: selectedType == "Take Money From Friend"
                                        ? const Color(0xFFFFEBEE)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selectedType == "Take Money From Friend"
                                          ? const Color(0xFFC62828)
                                          : const Color(0xFFE2E8F0),
                                      width: selectedType == "Take Money From Friend" ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: selectedType == "Take Money From Friend"
                                              ? const Color(0xFFC62828).withValues(alpha: 0.2)
                                              : Colors.grey.shade200,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_downward_rounded,
                                          size: 20,
                                          color: selectedType == "Take Money From Friend"
                                              ? const Color(0xFFC62828)
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "You Got",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: selectedType == "Take Money From Friend"
                                              ? const Color(0xFFC62828)
                                              : const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "You owe friend",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: selectedType == "Take Money From Friend"
                                              ? const Color(0xFFC62828)
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
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

                  // 4. Payment Mode Segment
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
                          "Payment Method",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _paymentModePill("Spent Online", "Online / UPI", Icons.credit_card_rounded, primary),
                            const SizedBox(width: 10),
                            _paymentModePill("Spent Cash", "Cash", Icons.payments_rounded, const Color(0xFFFFA000)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Date & Description
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
                      children: [
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
                        TextField(
                          controller: descriptionController,
                          maxLength: 150,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                          decoration: InputDecoration(
                            hintText: "Add note / reason (e.g. Dinner share, Cab fare)",
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: primary, size: 22),
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
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 6. Save CTA Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : getAllDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Save Friend Transaction",
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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

  Widget _paymentModePill(String modeKey, String label, IconData icon, Color color) {
    final isSelected = selectedMode == modeKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => selectedMode = modeKey),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? color : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
