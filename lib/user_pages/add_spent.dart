import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddSpent extends StatefulWidget {
  @override
  State<AddSpent> createState() => _addSpent();
}

class _addSpent extends State<AddSpent> {
  bool isLoading = false;

  TextEditingController Camount = TextEditingController();
  TextEditingController Cdescription = TextEditingController();

  DateTime selectedDate = DateTime.now();

  List<String> PaymentMode = [
    "Spent Online",
    "Spent Cash",
    "Spent Online For ADA",
    "Spent Cash For ADA",
    "Add CASH",
    "Add Online"
  ];

  String selectedMode = "Select Payment mode";

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
  String amount = Camount.text.trim();
  String description = Cdescription.text.trim();

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
    await StoreSpentOnDataBase(
      amount,
      description,
      selectedMode,
      "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
    );

    Fluttertoast.showToast(msg: "Expense added successfully");

    Navigator.pop(context, true);
  } catch (e) {
    Fluttertoast.showToast(msg: "Failed to save expense");
  }

  if (mounted) {
    setState(() {
      isLoading = false;
    });
  }
}

  Future<void> StoreSpentOnDataBase(
    String Amount,
    String Description,
    String selectedMode,
    String selected_date,
  ) async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String phone_number = sp.getString("phone_number")!;
    DatabaseReference myref = FirebaseDatabase.instance.ref(
      "Expenses/$phone_number",
    );
    String key = myref.push().key!;
    await myref.child(key).set({
      "key" : key,
      "phone_number": phone_number,
      "Amount": Amount,
      "Description": Description,
      "Payment_Mode": selectedMode,
      "Date": selected_date,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Add Spent",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight(800)),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Color(0xFF8BC24A),
      ),
      body: Stack(
        children: [
          Container(color: Color(0xFFE4D5A3)),
          Positioned(
            bottom: -200,
            child: Container(
              height: 500,
              width: 700,
              decoration: BoxDecoration(
                color: Color(0xff8BC24A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            child: Center(
              child: Container(
                height: 450,
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),

                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(right: 20, left: 20, top: 20),
                      child: TextField(
                        controller: Camount,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: "Amount",
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 3,
                              color: Color(0xFF8BC24A),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 3,
                              color: Color(0xFF8BC24A),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(right: 20, left: 20, top: 20),
                      child: TextField(
                        controller: Cdescription,
                        decoration: InputDecoration(
                          hintText: "Description",
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 3,
                              color: Color(0xFF8BC24A),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 3,
                              color: Color(0xFF8BC24A),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(right: 20, left: 20, top: 20),
                      child: TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText:
                              "Selected: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 3,
                              color: Color(0xFF8BC24A),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 3,
                              color: Color(0xFF8BC24A),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onTap: () => pickDate(),
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.only(right: 20, left: 20, top: 20),
                      child: DropdownMenu<String>(
                        initialSelection: selectedMode,
                        label: const Text("Select Payment Mode"),
                        dropdownMenuEntries: PaymentMode.map(
                          (item) => DropdownMenuEntry(value: item, label: item),
                        ).toList(),

                        onSelected: (value) {
                          setState(() {
                            selectedMode = value!;
                          });
                        },

                        inputDecorationTheme: InputDecorationTheme(
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 3,
                              color: Color(0xFF8BC24A),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              width: 3,
                              color: Color(0xFF8BC24A),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),

                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(left: 40, right: 40, top: 30),
                      child: ElevatedButton(
                        onPressed: () {
                          getAllDetails();
                        },
                        child: Text(
                          "Add Spent Details",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF8BC24A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if(isLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF8BC24A),),
              ),
            )
        ],
      ),
    );
  }
}
