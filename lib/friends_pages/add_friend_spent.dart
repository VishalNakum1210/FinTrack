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

  @override
  void initState() {
    super.initState();
    selectedMode = paymentModes.first;
    selectedType = categoryTypes.first;
  }

  @override
  void dispose() {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF2),
      appBar: AppBar(
        title: const Text(
          "Add Friend Transaction",
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
                      "Friend Ledger Entry",
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
                      decoration: inputDecoration("Enter Amount (₹)"),
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
                      ),
                      onTap: pickDate,
                    ),

                    const SizedBox(height: 18),

                    DropdownMenu<String>(
                      width: MediaQuery.of(context).size.width - 84,
                      initialSelection: selectedType,
                      label: const Text("Select Transaction Type"),
                      dropdownMenuEntries: categoryTypes
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
                            selectedType = value;
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
                        child: const Text(
                          "Save Friend Expense",
                          style: TextStyle(
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
