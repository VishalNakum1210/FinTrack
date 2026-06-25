import 'package:FinTrack/FriendsPages/addFriends.dart';
import 'package:FinTrack/FriendsPages/specificFriendPage.dart';
import 'package:FinTrack/GetInformation/GetFriendDetails.dart';
import 'package:FinTrack/GetInformation/GetTotalFriendExpenses.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendPage extends StatefulWidget {
  @override
  State<FriendPage> createState() => _friendPage();
}

class _friendPage extends State<FriendPage> {
  bool isLoading = false;
  List<Map<String, dynamic>>? friendRecord = null;
  List<String> allExpenses = ["0", "0"];

  Future<void> getDetails() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences sp = await SharedPreferences.getInstance();
    String? phone_number = sp.getString("phone_number");
    friendRecord = (await getFriendDetails(phone_number!));
    allExpenses = (await getTotalFriendExpenses(phone_number));
    setState(() {
      isLoading = false;
    });
  }

  Future<void> deleteFriend(String friend_number) async {
    try {
      setState(() {
        isLoading = true;
      });
      SharedPreferences sp = await SharedPreferences.getInstance();
      String phone_number = sp.getString("phone_number")!;
      DatabaseReference deleteRef = FirebaseDatabase.instance.ref(
        "Friends/$phone_number/$friend_number",
      );
      await deleteRef.remove();
      friendRecord!.clear();
      await getDetails();
    } catch (e) {
      Fluttertoast.showToast(msg: "Not connected $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
    Color primaryColor = const Color(0xFF8BC24A);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 230, 230, 230),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: const Text(
          "Friend Ledger",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),

      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF8BC24A), Color(0xFF7CB342)],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: .35),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "You Will Get",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        NumberFormat.currency(
                          locale: 'en_IN',
                          symbol: '₹',
                          decimalDigits: 0,
                        ).format(int.tryParse(allExpenses[0])),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 45, width: 1, color: Colors.white30),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "You Will Give",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      SizedBox(height: 5),

                      Text(
                        NumberFormat.currency(
                          locale: 'en_IN',
                          symbol: '₹',
                          decimalDigits: 0,
                        ).format(int.tryParse(allExpenses[1])),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search friend...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // Friends Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                const Text(
                  "Friends",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                const Spacer(),

                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddFriends()),
                    );

                    if (result == true) {
                      getDetails();
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text("Add"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Friend List
          Expanded(
            child: (friendRecord != null)
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: friendRecord!.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                        onLongPress: () async {
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
                                    deleteFriend(friendRecord![index]["friend_number"]);
                                  },
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );
                        },
                        onTap: () async {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Specificfriendpage(
                                friend_number:
                                    friendRecord![index]["friend_number"],
                              ),
                            ),
                          ).then((_) {
                            getDetails();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),

                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: primaryColor.withValues(alpha: .15),
                                child: Text(
                                  (friendRecord![index]["friend_name"][0])
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Name & Number
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friendRecord![index]["friend_name"],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      friendRecord![index]["friend_number"],
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Get & Give
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      NumberFormat.currency(
                                        locale: 'en_IN',
                                        symbol: 'Get ₹',
                                        decimalDigits: 0,
                                      ).format(
                                        int.parse(
                                          friendRecord![index]["total_get"],
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      NumberFormat.currency(
                                        locale: 'en_IN',
                                        symbol: 'Give ₹',
                                        decimalDigits: 0,
                                      ).format(
                                        int.parse(
                                          friendRecord![index]["total_give"],
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : (isLoading)
                ? Container(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.green),
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
