import 'package:FinTrack/GetInformation/SessionManager.dart';
import 'package:FinTrack/providers/expense_provider.dart';
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

  @override
  void initState() {
    super.initState();
    selectedMode = paymentModes.first;
    selectedCategory = categories.first;
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
      lastDate: DateTime(2100),
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

    if (int.tryParse(amount) == null || (int.tryParse(amount) ?? 0) <= 0) {
      Fluttertoast.showToast(msg: "Please enter a valid amount");
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
      final success = await context.read<ExpenseProvider>().addExpense(
        phoneNumber: phone,
        amount: amount,
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
                          "Save Transaction",
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