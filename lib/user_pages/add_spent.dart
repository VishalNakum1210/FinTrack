import 'package:FinTrack/FriendsPages/split_bill_page.dart';
import 'package:FinTrack/GetInformation/session_manager.dart';
import 'package:FinTrack/providers/expense_provider.dart';
import 'package:FinTrack/providers/friend_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AddSpent extends StatefulWidget {
  const AddSpent({super.key});

  @override
  State<AddSpent> createState() => _AddSpentState();
}

class _AddSpentState extends State<AddSpent> {
  bool isLoading = false;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  final List<String> paymentModes = const [
    "Spent Online",
    "Spent Cash",
    "Add CASH",
    "Add Online",
  ];

  final List<String> categories = const [
    "Food",
    "Shopping",
    "Transport",
    "Education",
    "HealthCare",
    "Entertainment",
    "Add Money",
    "Other",
  ];

  late String selectedMode;
  late String selectedCategory;

  // 👥 1-Tap Split with Friend State
  bool isSplitWithFriend = false;
  String? selectedFriendNumber;
  String? selectedFriendName;

  void _onAmountChanged() {
    if (isSplitWithFriend && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    selectedMode = paymentModes.first;
    selectedCategory = categories.first;

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

  Future<void> getAllDetails() async {
    String rawAmount = amountController.text.trim();
    String description = descriptionController.text.trim();

    if (rawAmount.isEmpty || description.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill in all fields");
      return;
    }

    final totalAmount = double.tryParse(rawAmount.replaceAll(',', '').trim());
    if (totalAmount == null || totalAmount <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid amount");
      return;
    }

    final isSpending = selectedMode.startsWith("Spent");
    if (isSplitWithFriend && isSpending && selectedFriendNumber == null) {
      Fluttertoast.showToast(msg: "Please select a friend to split the bill with");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final phone = await SessionManager.getPhoneNumber() ?? "";
      if (phone.isEmpty) {
        Fluttertoast.showToast(msg: "User session not found");
        return;
      }

      String formattedDate = DateFormat('d/M/yyyy').format(selectedDate);
      if (!mounted) return;

      final expenseProvider = context.read<ExpenseProvider>();
      final friendProvider = context.read<FriendProvider>();

      if (isSplitWithFriend && isSpending && selectedFriendNumber != null) {
        final friendShare = (totalAmount * 0.5 * 100).round() / 100;
        final myShare = ((totalAmount - friendShare) * 100).round() / 100;

        final myShareStr = myShare.truncateToDouble() == myShare ? myShare.toInt().toString() : myShare.toStringAsFixed(2);
        final friendShareStr = friendShare.truncateToDouble() == friendShare ? friendShare.toInt().toString() : friendShare.toStringAsFixed(2);
        final totalAmountStr = totalAmount.truncateToDouble() == totalAmount ? totalAmount.toInt().toString() : totalAmount.toStringAsFixed(2);

        // Single atomic multi-path update for Passbook + Friend Ledger
        final splitSuccess = await friendProvider.atomicSplitBill(
          userPhone: phone,
          friendNumber: selectedFriendNumber!,
          myShareAmount: myShareStr,
          friendShareAmount: friendShareStr,
          totalAmount: totalAmountStr,
          description: description,
          date: formattedDate,
          category: selectedCategory,
          paymentMode: selectedMode,
        );

        if (splitSuccess) {
          await expenseProvider.fetchExpenses(phone);
          Fluttertoast.showToast(
            msg: "Saved! ₹$myShareStr in Passbook & ₹$friendShareStr added to $selectedFriendName's ledger",
          );
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(msg: "Failed to save split transaction");
        }
      } else {
        final rawAmountFormatted = totalAmount.truncateToDouble() == totalAmount
            ? totalAmount.toInt().toString()
            : totalAmount.toStringAsFixed(2);

        // Standard single transaction
        final success = await expenseProvider.addExpense(
          phoneNumber: phone,
          amount: rawAmountFormatted,
          description: description,
          paymentMode: selectedMode,
          date: formattedDate,
          category: selectedCategory,
        );

        if (success) {
          Fluttertoast.showToast(msg: "Transaction added successfully");
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          Fluttertoast.showToast(msg: "Failed to save transaction");
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save transaction");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(width: 2, color: Color(0xFF8BC24A)),
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(width: 2.5, color: Color(0xFF8BC24A)),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  InputDecorationTheme inputTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(width: 2, color: Color(0xFF8BC24A)),
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(width: 2.5, color: Color(0xFF8BC24A)),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendProvider = context.watch<FriendProvider>();
    final friends = friendProvider.friends;
    final isSpending = selectedMode.startsWith("Spent");
    final currentAmount = double.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0.0;
    final mySharePreview = ((currentAmount * 0.5) * 100).round() / 100;
    final friendSharePreview = ((currentAmount - mySharePreview) * 100).round() / 100;

    final mySharePreviewStr = mySharePreview.truncateToDouble() == mySharePreview ? mySharePreview.toInt().toString() : mySharePreview.toStringAsFixed(2);
    final friendSharePreviewStr = friendSharePreview.truncateToDouble() == friendSharePreview ? friendSharePreview.toInt().toString() : friendSharePreview.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF2),
      appBar: AppBar(
        title: const Text(
          "Add Transaction",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF8BC24A),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "New Transaction Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8BC24A),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: inputDecoration("Enter Total Amount (₹)"),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: descriptionController,
                      decoration: inputDecoration("Enter Description / Note"),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      readOnly: true,
                      decoration: inputDecoration(
                        "Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}",
                      ).copyWith(
                        suffixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF8BC24A)),
                      ),
                      onTap: pickDate,
                    ),

                    const SizedBox(height: 18),

                    DropdownMenu<String>(
                      width: MediaQuery.of(context).size.width - 84,
                      initialSelection: selectedCategory,
                      label: const Text("Select Category"),
                      dropdownMenuEntries: categories
                          .map(
                            (item) => DropdownMenuEntry(
                              value: item,
                              label: item,
                            ),
                          )
                          .toList(),
                      onSelected: (value) {
                        if (value != null) {
                          setState(() {
                            selectedCategory = value;
                          });
                        }
                      },
                      inputDecorationTheme: inputTheme(),
                    ),

                    const SizedBox(height: 18),

                    DropdownMenu<String>(
                      width: MediaQuery.of(context).size.width - 84,
                      initialSelection: selectedMode,
                      label: const Text("Select Payment Mode"),
                      dropdownMenuEntries: paymentModes
                          .map(
                            (item) => DropdownMenuEntry(
                              value: item,
                              label: item,
                            ),
                          )
                          .toList(),
                      onSelected: (value) {
                        if (value != null) {
                          setState(() {
                            selectedMode = value;
                          });
                        }
                      },
                      inputDecorationTheme: inputTheme(),
                    ),

                    // 👥 1-Tap Bill Split Section (Available for Expense transactions)
                    if (isSpending) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSplitWithFriend ? const Color(0xFFF1F8E9) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSplitWithFriend ? const Color(0xFF8BC24A) : Colors.grey.shade300,
                            width: isSplitWithFriend ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isSplitWithFriend ? const Color(0xFF8BC24A).withValues(alpha: 0.2) : Colors.grey.shade200,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.group_rounded,
                                        size: 20,
                                        color: isSplitWithFriend ? const Color(0xFF558B2F) : Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "Split Bill with Friend",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14.5,
                                        color: isSplitWithFriend ? const Color(0xFF33691E) : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Switch.adaptive(
                                  value: isSplitWithFriend,
                                  activeTrackColor: const Color(0xFF8BC24A),
                                  activeThumbColor: Colors.white,
                                  onChanged: (val) {
                                    setState(() {
                                      isSplitWithFriend = val;
                                      if (val && friends.isNotEmpty && selectedFriendNumber == null) {
                                        selectedFriendNumber = friends.first["friend_number"];
                                        selectedFriendName = friends.first["friend_name"];
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),

                            if (isSplitWithFriend) ...[
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              if (friends.isEmpty)
                                Text(
                                  "No friends found. Add friends in the Friends tab to split bills.",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                                )
                              else ...[
                                DropdownMenu<String>(
                                  width: MediaQuery.of(context).size.width - 116,
                                  initialSelection: selectedFriendNumber ?? friends.first["friend_number"],
                                  label: const Text("Select Friend"),
                                  dropdownMenuEntries: friends.map((f) {
                                    final name = (f["friend_name"] ?? "Friend").toString();
                                    final number = (f["friend_number"] ?? "").toString();
                                    return DropdownMenuEntry(
                                      value: number,
                                      label: "$name ($number)",
                                    );
                                  }).toList(),
                                  onSelected: (val) {
                                    if (val != null) {
                                      final matched = friends.firstWhere(
                                        (f) => f["friend_number"] == val,
                                        orElse: () => {"friend_name": "Friend"},
                                      );
                                      setState(() {
                                        selectedFriendNumber = val;
                                        selectedFriendName = matched["friend_name"];
                                      });
                                    }
                                  },
                                  inputDecorationTheme: inputTheme(),
                                ),

                                if (currentAmount > 0) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF8BC24A).withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Your Expense: ₹$mySharePreviewStr",
                                          style: const TextStyle(
                                            color: Color(0xFF558B2F),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        Text(
                                          "Friend Owes: ₹$friendSharePreviewStr",
                                          style: const TextStyle(
                                            color: Color(0xFFE65100),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const SplitBillPage()),
                                        );
                                      },
                                      icon: const Icon(Icons.group_work_rounded, size: 16, color: Color(0xFF558B2F)),
                                      label: const Text(
                                        "Split with 2+ friends? Open Group Splitter ➔",
                                        style: TextStyle(
                                          color: Color(0xFF558B2F),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : getAllDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8BC24A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isSplitWithFriend ? "Save & Split Bill" : "Save Transaction",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF8BC24A)),
              ),
            ),
        ],
      ),
    );
  }
}