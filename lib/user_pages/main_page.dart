import 'package:account/GetInformation/GetAllInformation.dart';
import 'package:account/GetInformation/GetAllRecords.dart';
import 'package:account/user_pages/add_spent.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class UserMainPage extends StatefulWidget {
  @override
  State<UserMainPage> createState() => _userMainPage();
}

class _userMainPage extends State<UserMainPage> {
  bool isLoading = true;
  String? name;
  String totalExpanses = "0";
  List<String> allDetails = ["0", "0", "0", "0"];
  List<Map<String, dynamic>>? records;

  Future<void> getDetails() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String phone_number = sp.getString("phone_number")!;
    allDetails = await getAllInformation(phone_number);
    records = await allRecords(phone_number, "All");
    setState(() {
      name = sp.getString("username") ?? "";
      isLoading = false;
    });
  }

  String formatIndianNumber(int number) {
    return NumberFormat('#,##,##0', 'en_IN').format(number);
  }

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // elevation: 0,
        title: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 5, right: 10),
              height: 50,
              width: 50,
              child: const CircleAvatar(
                radius: 25,
                backgroundImage: AssetImage(
                  "assets/image/AccountApplicationLogo.jpg",
                ),
              ),
            ),
            Text(
              "Welcome, ${name ?? ''}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF8BC24A),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
      ),

      body: Container(
        color: const Color(0xFF8BC24A),
        height: double.infinity,
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  padding: EdgeInsets.all(10),
                  margin: const EdgeInsets.only(left: 10, right: 10, top: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFE4D5A3),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 85,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          color: Colors.white,
                        ),
                        child: InnerBox(
                          "CASH EXpenses",
                          "Total CASH",
                          allDetails[0],
                          allDetails[1],
                        ),
                      ),
                      Container(
                        height: 85,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          color: Colors.white,
                        ),
                        child: InnerBox(
                          "ONLINE EXpenses",
                          "Total ONLINE",
                          allDetails[2],
                          allDetails[3],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    // height: 410,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(
                      left: 10,
                      right: 10,
                      top: 20,
                      bottom: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFE4D5A3),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: (records != null)
                        ? ListView.builder(
                            itemCount: records!.length,
                            itemBuilder: (context, index) {
                              return Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.white,
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(records![index]["Date"]),
                                      Text(records![index]["Description"]),
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
                                    ).format(
                                      int.tryParse(records![index]["Amount"]),
                                    ),
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
                              );
                            },
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
                ),
              ],
            ),

            if (isLoading)
              Positioned(
                child: Container(
                  height: double.infinity,
                  width: double.infinity,
                  color: Colors.black87,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF8BC24A)),
                  ),
                ),
              ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddSpent()),
          );

          if (result == true) {
            getDetails();
          }
        },
        backgroundColor: Colors.white,
        child: Image.asset("assets/image/GreenPlus.png", height: 30, width: 30),
      ),
    );
  }

  Widget InnerBox(
    String LeftExpenses,
    String RigthGain,
    String Expenses,
    String Gain,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      "assets/image/ExpensesPic2.png",
                      height: 22,
                      width: 22,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "$LeftExpenses",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '-₹',
                      decimalDigits: 0,
                    ).format(int.tryParse(Expenses)),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      "assets/image/GainPic.png",
                      height: 22,
                      width: 22,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "$RigthGain",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '+₹',
                      decimalDigits: 0,
                    ).format(int.tryParse(Gain)),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
