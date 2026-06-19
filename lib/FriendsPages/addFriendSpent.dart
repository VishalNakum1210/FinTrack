import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddFriendExpenses extends StatefulWidget {
  final String friend_number;
  const AddFriendExpenses({
    super.key,
    required this.friend_number
  });
  @override
  State<AddFriendExpenses> createState() => _addFriendExpenses();
}

class _addFriendExpenses extends State<AddFriendExpenses> {
  bool isLoading = false;

  TextEditingController Camount = TextEditingController();
  TextEditingController Cdescription = TextEditingController();

  DateTime selectedDate = DateTime.now();

  List<String> PaymentMode = [
    "Spent Online",
    "Spent Cash",
  ];

  List<String> Catagory = [
    "Give Money To Friend",
    "Take Money From Friend"
  ];

  String selectedMode = "Select Payment mode";
  String selectedType = "Select Type";

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
        selectedType,
      );

      Fluttertoast.showToast(msg: "Expense added successfully");

      Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save expense");
      print(e);
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
  String selectedCategory,
) async {
  SharedPreferences sp = await SharedPreferences.getInstance();
  String phone_number = sp.getString("phone_number")!;

  // Add Record
  DatabaseReference recordRef = FirebaseDatabase.instance.ref(
    "Friends/$phone_number/${widget.friend_number}/Records",
  );

  String key = recordRef.push().key!;

  await recordRef.child(key).set({
    "key": key,
    "Amount": Amount,
    "Description": Description,
    "Payment_Mode": selectedMode,
    "Date": selected_date,
    "Type": selectedCategory,
    "timestamp": ServerValue.timestamp,
  });

  // Friend Details Reference
  DatabaseReference friendRef = FirebaseDatabase.instance.ref(
    "Friends/$phone_number/${widget.friend_number}",
  );

  DataSnapshot snapshot = await friendRef.get();

  int totalGive = int.tryParse(
        snapshot.child("total_give").value?.toString() ?? "0",
      ) ??
      0;

  int totalGet = int.tryParse(
        snapshot.child("total_get").value?.toString() ?? "0",
      ) ??
      0;

  if (selectedCategory == "Take Money From Friend") {
    totalGive += int.parse(Amount);

    await friendRef.update({
      "total_give": totalGive.toString(),
    });
  } else {
    totalGet += int.parse(Amount);

    await friendRef.update({
      "total_get": totalGet.toString(),
    });
  }
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
                height: 500,
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),

                child: SingleChildScrollView(
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
                        child: DropdownMenu(
                          initialSelection: selectedType,
                          label: Text("Select Type"),
                          dropdownMenuEntries: Catagory.map(
                            (item) =>
                                DropdownMenuEntry(value: item, label: item),
                          ).toList(),

                          onSelected: (value) {
                            setState(() {
                              selectedType = value!;
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
                        margin: EdgeInsets.only(right: 20, left: 20, top: 20),
                        child: DropdownMenu<String>(
                          initialSelection: selectedMode,
                          label: const Text("Select Payment Mode"),
                          dropdownMenuEntries: PaymentMode.map(
                            (item) =>
                                DropdownMenuEntry(value: item, label: item),
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
          ),
          if (isLoading)
            Container(
              color: Colors.black87,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF8BC24A)),
              ),
            ),
        ],
      ),
    );
  }
}
