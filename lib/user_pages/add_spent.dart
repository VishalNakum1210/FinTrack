import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final List<String> paymentModes = [
    "Spent Online",
    "Spent Cash",
    "Add CASH",
    "Add Online",
  ];

  final List<String> categories = [
    "Shopping",
    "Food",
    "Transport",
    "Education",
    "HealthCare",
    "Entertainment",
    "Add Money",
    "Other",
  ];

  String selectedMode = "Select Payment mode";
  String selectedCategory = "Select Category";

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

  void getAllDetails() async {
    String amount = amountController.text.trim();
    String description = descriptionController.text.trim();

    if (amount.isEmpty ||
        description.isEmpty ||
        selectedMode == "Select Payment mode") {
      Fluttertoast.showToast(msg: "Please Enter All Values");

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await storeSpentOnDatabase(
        amount,
        description,
        selectedMode,
        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
        selectedCategory,
      );

      Fluttertoast.showToast(msg: "Transaction Added Successfully");

      Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save transaction");
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> storeSpentOnDatabase(
    String amount,
    String description,
    String mode,
    String date,
    String category,
  ) async {
    SharedPreferences sp = await SharedPreferences.getInstance();

    String phone = sp.getString("phone_number")!;

    DatabaseReference ref = FirebaseDatabase.instance.ref("Expenses/$phone");

    String key = ref.push().key!;

    await ref.child(key).set({
      "key": key,
      "phone_number": phone,
      "Amount": amount,
      "Description": description,
      "Payment_Mode": mode,
      "Date": date,
      "Category": category,
      "timestamp": ServerValue.timestamp,
    });
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,

      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(width: 3, color: Color(0xFF8BC24A)),

        borderRadius: BorderRadius.circular(20),
      ),

      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(width: 3, color: Color(0xFF8BC24A)),

        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  InputDecorationTheme inputTheme() {
    return InputDecorationTheme(
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(width: 3, color: Color(0xFF8BC24A)),

        borderRadius: BorderRadius.circular(20),
      ),

      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(width: 3, color: Color(0xFF8BC24A)),

        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add Transaction",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),

        iconTheme: const IconThemeData(color: Colors.white),

        backgroundColor: const Color(0xFF8BC24A),
      ),

      body: Stack(
        children: [
          Container(color: const Color(0xFFE4D5A3)),

          Positioned(
            bottom: -200,

            left: -50,

            child: Container(
              height: 500,

              width: 700,

              decoration: const BoxDecoration(
                color: Color(0xff8BC24A),

                shape: BoxShape.circle,
              ),
            ),
          ),

          Center(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,

              margin: const EdgeInsets.symmetric(horizontal: 20),

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(30),
              ),

              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    TextField(
                      controller: amountController,

                      keyboardType: TextInputType.number,

                      decoration: inputDecoration("Enter Amount"),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: descriptionController,

                      decoration: inputDecoration("Enter Description"),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      readOnly: true,

                      decoration: inputDecoration(
                        "Date : ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                      ),

                      onTap: pickDate,
                    ),

                    const SizedBox(height: 20),

                    DropdownMenu<String>(
                      width: MediaQuery.of(context).size.width - 80,

                      initialSelection: selectedCategory,

                      label: const Text("Select Category"),

                      dropdownMenuEntries: categories
                          .map(
                            (item) =>
                                DropdownMenuEntry(value: item, label: item),
                          )
                          .toList(),

                      onSelected: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },

                      inputDecorationTheme: inputTheme(),
                    ),

                    const SizedBox(height: 20),

                    DropdownMenu<String>(
                      width: MediaQuery.of(context).size.width - 80,

                      initialSelection: selectedMode,

                      label: const Text("Select Payment Mode"),

                      dropdownMenuEntries: paymentModes
                          .map(
                            (item) =>
                                DropdownMenuEntry(value: item, label: item),
                          )
                          .toList(),

                      onSelected: (value) {
                        setState(() {
                          selectedMode = value!;
                        });
                      },

                      inputDecorationTheme: inputTheme(),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,

                      child: ElevatedButton(
                        onPressed: getAllDetails,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8BC24A),

                          padding: const EdgeInsets.symmetric(vertical: 15),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),

                        child: const Text(
                          "Save",

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
              color: Colors.black87,

              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF8BC24A)),
              ),
            ),
        ],
      ),
    );
  }
}