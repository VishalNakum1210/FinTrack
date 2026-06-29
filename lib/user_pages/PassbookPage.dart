// import 'package:FinTrack/GetInformation/GetAllRecords.dart';
// import 'package:FinTrack/GetInformation/GetTotalExpenses.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class Passbookpage extends StatefulWidget {
//   @override
//   State<Passbookpage> createState() => _passbookPage();
// }

// class _passbookPage extends State<Passbookpage> {
//   bool isLoading = false;
//   String totalAmount = "0";

//   String selectedType = "All";
//   List<Map<String, dynamic>>? records = null;

//   Widget categoryChip(String title) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 5),
//       child: ChoiceChip(
//         label: Text(title),
//         selected: selectedType == title,
//         onSelected: (value) async {
//           filterExpenses(title);
//         },
//       ),
//     );
//   }

//   Future<void> filterExpenses(String type) async {
//     setState(() {
//       isLoading = true;
//       records = null;
//       totalAmount = "0";
//     });
//     SharedPreferences sp = await SharedPreferences.getInstance();
//     records = (await allRecords(sp.getString("phone_number")!, type));
//     totalAmount = await getTotalExpenses(sp.getString("phone_number")!, type);
//     setState(() {
//       isLoading = false;
//       selectedType = type;
//     });
//   }

//   String formatIndianNumber(int number) {
//     return NumberFormat('#,##,##0', 'en_IN').format(number);
//   }

//   Future<void> deleteRecord(String key) async {
//     setState(() {
//       isLoading = true;
//     });
//     try {
//       SharedPreferences sp = await SharedPreferences.getInstance();
//       String phone_number = sp.getString("phone_number")!;
//       DatabaseReference myref = FirebaseDatabase.instance.ref(
//         "Expenses/$phone_number/$key",
//       );

//       await myref.remove();
//       records!.clear();
//       await filterExpenses(selectedType);
//       Fluttertoast.showToast(msg: "Recored Deleted Successfully");
//     } catch (e) {
//       Fluttertoast.showToast(msg: "Not Connected $e");
//     } finally {
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     filterExpenses("All");
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           "Passbook",
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: Color(0xFF8BC24A),
//           ),
//         ),
//       ),
//       body: Column(
//         children: [
//           // Category Filter
//           Container(
//             margin: EdgeInsets.symmetric(horizontal: 9),
//             child: SizedBox(
//               height: 100,
//               child: ListView(
//                 scrollDirection: Axis.horizontal,
//                 children: [
//                   Column(
//                     children: [
//                       Row(
//                         children: [
//                           categoryChip("All"),
//                           categoryChip("Spent Cash"),
//                           categoryChip("Spent Online"),
//                           categoryChip("Add CASH"),
//                           categoryChip("Add Online"),
//                         ],
//                       ),
//                       Row(
//                         children: [
//                           categoryChip("Food"),
//                           categoryChip("Shopping"),
//                           categoryChip("Transport"),
//                           categoryChip("Entertainment"),
//                           categoryChip("HealthCare"),
//                           categoryChip("Other"),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           // Total Amount
//           Container(
//             margin: const EdgeInsets.all(15),
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(
//                 colors: [Color(0xFF8BC24A), Color(0xFF689F38)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.greenAccent.withOpacity(0.3),
//                   blurRadius: 15,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: Column(
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       height: 40,
//                       width: 55,
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(15),
//                       ),
//                       child: Icon(
//                         selectedType == "All"
//                             ? Icons.receipt_long_rounded
//                             : selectedType.contains("Online")
//                             ? Icons.credit_card_rounded
//                             : Icons.payments_rounded,
//                         color: Colors.white,
//                         size: 25,
//                       ),
//                     ),

//                     const SizedBox(width: 15),

//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             selectedType,
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),

//                           const SizedBox(height: 3),

//                           const Text(
//                             "Current Filter",
//                             style: TextStyle(
//                               color: Colors.white70,
//                               fontSize: 13,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),

//                 const SizedBox(height: 15),

//                 Container(
//                   width: double.infinity,
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 10,
//                     horizontal: 15,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.15),
//                     borderRadius: BorderRadius.circular(15),
//                   ),
//                   child: Column(
//                     children: [
//                       const Text(
//                         "Total Expanses",
//                         style: TextStyle(color: Colors.white70, fontSize: 14),
//                       ),

//                       const SizedBox(height: 5),

//                       Text(
//                         "₹${formatIndianNumber(int.tryParse(totalAmount) ?? 0)}",
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 25,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Expense Records
//           Expanded(
//             child: (records != null)
//                 ? ListView.builder(
//                     itemCount: records!.length,
//                     itemBuilder: (context, index) {
//                       return InkWell(
//                         onTap: () {
//                           showDialog(
//                             context: context,
//                             builder: (context) => AlertDialog(
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(20),
//                               ),
//                               title: const Text("Delete Record"),
//                               content: const Text(
//                                 "Are you sure you want to delete this record?",
//                               ),
//                               actions: [
//                                 TextButton(
//                                   onPressed: () {
//                                     Navigator.pop(context);
//                                   },
//                                   child: const Text("Cancel"),
//                                 ),

//                                 ElevatedButton(
//                                   style: ElevatedButton.styleFrom(
//                                     backgroundColor: Colors.red,
//                                     foregroundColor: Colors.white,
//                                   ),
//                                   onPressed: () async {
//                                     Navigator.pop(context);

//                                     await deleteRecord(records![index]["key"]);
//                                   },
//                                   child: const Text("Delete"),
//                                 ),
//                               ],
//                             ),
//                           );
//                         },
//                         child: Card(
//                           elevation: 3,
//                           margin: EdgeInsets.symmetric(
//                             horizontal: 10,
//                             vertical: 5,
//                           ),
//                           color:
//                               (records![index]["Payment_Mode"] == "Add CASH" ||
//                                   records![index]["Payment_Mode"] ==
//                                       "Add Online")
//                               ? Colors.green.shade100
//                               : Colors.red.shade100,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                           child: ListTile(
//                             leading: CircleAvatar(
//                               backgroundColor:
//                                   (records![index]["Payment_Mode"] ==
//                                           "Add CASH" ||
//                                       records![index]["Payment_Mode"] ==
//                                           "Add Online")
//                                   ? Colors.green.shade100
//                                   : Colors.red.shade100,
//                               child: Image.asset(
//                                 (records![index]["Payment_Mode"] ==
//                                             "Add CASH" ||
//                                         records![index]["Payment_Mode"] ==
//                                             "Add Online")
//                                     ? "assets/image/GetPic.png"
//                                     : "assets/image/SpentPic.png",
//                               ),
//                             ),
//                             title: Text(
//                               records![index]["Category"],
//                               style: TextStyle(fontWeight: FontWeight.bold),
//                             ),
//                             subtitle: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(records![index]["Date"]),
//                                 Text(
//                                   "Desc : " + records![index]["Description"],
//                                 ),
//                                 Text(
//                                   "Payment: ${records![index]["Payment_Mode"]}",
//                                 ),
//                               ],
//                             ),
//                             trailing: Text(
//                               NumberFormat.currency(
//                                 locale: 'en_IN',
//                                 symbol: '₹',
//                                 decimalDigits: 0,
//                               ).format(int.tryParse(records![index]["Amount"])),
//                               style: TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                                 color:
//                                     (records![index]["Payment_Mode"] ==
//                                             "Add CASH" ||
//                                         records![index]["Payment_Mode"] ==
//                                             "Add Online")
//                                     ? Colors.green
//                                     : Colors.red,
//                               ),
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   )
//                 : isLoading
//                 ? Container(
//                     height: double.infinity,
//                     width: double.infinity,
//                     color: Colors.white70,

//                     child: Center(
//                       child: CircularProgressIndicator(
//                         color: Color(0xFF8BC24A),
//                       ),
//                     ),
//                   )
//                 : Container(
//                     height: double.infinity,
//                     width: double.infinity,
//                     child: Center(
//                       child: Text(
//                         "No Data Found",
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 30,
//                           color: Colors.green,
//                         ),
//                       ),
//                     ),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:FinTrack/GetInformation/GetAllRecords.dart';
import 'package:FinTrack/GetInformation/GetTotalExpenses.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Passbookpage extends StatefulWidget {
  @override
  State<Passbookpage> createState() => _passbookPage();
}

class _passbookPage extends State<Passbookpage> {
  bool isLoading = false;
  String totalAmount = "0";

  String selectedType = "All";
  List<Map<String, dynamic>>? records = null;

  Widget categoryChip(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ChoiceChip(
        label: Text(title),
        selected: selectedType == title,
        onSelected: (value) async {
          filterExpenses(title);
        },
      ),
    );
  }

  Future<void> filterExpenses(String type) async {
    setState(() {
      isLoading = true;
      records = null;
      totalAmount = "0";
    });
    SharedPreferences sp = await SharedPreferences.getInstance();
    records = (await allRecords(sp.getString("phone_number")!, type));
    totalAmount = await getTotalExpenses(sp.getString("phone_number")!, type);
    setState(() {
      isLoading = false;
      selectedType = type;
    });
  }

  String formatIndianNumber(int number) {
    return NumberFormat('#,##,##0', 'en_IN').format(number);
  }

  Future<void> deleteRecord(String key) async {
    setState(() {
      isLoading = true;
    });
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();
      String phone_number = sp.getString("phone_number")!;
      DatabaseReference myref = FirebaseDatabase.instance.ref(
        "Expenses/$phone_number/$key",
      );

      await myref.remove();
      records!.clear();
      await filterExpenses(selectedType);
      Fluttertoast.showToast(msg: "Recored Deleted Successfully");
    } catch (e) {
      Fluttertoast.showToast(msg: "Not Connected $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    filterExpenses("All");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Passbook",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF8BC24A),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category Filter
          Container(
            margin: EdgeInsets.symmetric(horizontal: 9),
            child: SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          categoryChip("All"),
                          categoryChip("Spent Cash"),
                          categoryChip("Spent Online"),
                          categoryChip("Add CASH"),
                          categoryChip("Add Online"),
                        ],
                      ),
                      Row(
                        children: [
                          categoryChip("Food"),
                          categoryChip("Shopping"),
                          categoryChip("Transport"),
                          categoryChip("Entertainment"),
                          categoryChip("HealthCare"),
                          categoryChip("Other"),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Total Amount
          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8BC24A), Color(0xFF689F38)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      height: 40,
                      width: 55,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        selectedType == "All"
                            ? Icons.receipt_long_rounded
                            : selectedType.contains("Online")
                            ? Icons.credit_card_rounded
                            : Icons.payments_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 3),

                          const Text(
                            "Current Filter",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Total Expanses",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        "₹${formatIndianNumber(int.tryParse(totalAmount) ?? 0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Expense Records
          Expanded(
            child: (records != null)
                ? ListView.builder(
                    itemCount: records!.length,
                    itemBuilder: (context, index) {
                      return InkWell(
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

                                    await deleteRecord(records![index]["key"]);
                                  },
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Card(
                          elevation: 3,
                          margin: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          color:
                              (records![index]["Payment_Mode"] == "Add CASH" ||
                                  records![index]["Payment_Mode"] ==
                                      "Add Online")
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  (records![index]["Payment_Mode"] ==
                                          "Add CASH" ||
                                      records![index]["Payment_Mode"] ==
                                          "Add Online")
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              child: Image.asset(
                                (records![index]["Payment_Mode"] ==
                                            "Add CASH" ||
                                        records![index]["Payment_Mode"] ==
                                            "Add Online")
                                    ? "assets/image/GetPic.png"
                                    : "assets/image/SpentPic.png",
                              ),
                            ),
                            title: Text(
                              records![index]["Category"],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(records![index]["Date"]),
                                Text(
                                  "Desc : " + records![index]["Description"],
                                ),
                                Text(
                                  "Payment: ${records![index]["Payment_Mode"]}",
                                ),
                              ],
                            ),
                            trailing: Text(
                              NumberFormat.currency(
                                locale: 'en_IN',
                                symbol: '₹',
                                decimalDigits: 0,
                              ).format(int.tryParse(records![index]["Amount"])),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    (records![index]["Payment_Mode"] ==
                                            "Add CASH" ||
                                        records![index]["Payment_Mode"] ==
                                            "Add Online")
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : isLoading
                ? Container(
                    height: double.infinity,
                    width: double.infinity,
                    color: Colors.white70,

                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8BC24A),
                      ),
                    ),
                  )
                : Container(
                    height: double.infinity,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        "No Data Found",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
