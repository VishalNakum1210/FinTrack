import 'package:account/FriendsPages/addFriends.dart';
import 'package:account/GetInformation/GetFriendDetails.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendPage extends StatefulWidget {
  @override
  State<FriendPage> createState() => _friendPage();
}

class _friendPage extends State<FriendPage> {
  List<Map<String, dynamic>>? friendRecord = null;

  void getDetails() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String? phone_number = sp.getString("phone_number");
    friendRecord = (await getFriendDetails(phone_number!));
    setState(() {});
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
      backgroundColor: const Color.fromARGB(255, 195, 224, 196),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryColor,
        title: const Text(
          "Friend Accounts",
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
                  color: primaryColor.withOpacity(.35),
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
                    children: const [
                      Text(
                        "You Will Get",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      SizedBox(height: 5),

                      Text(
                        "₹12,500",
                        style: TextStyle(
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
                    children: const [
                      Text(
                        "You Will Give",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),

                      SizedBox(height: 5),

                      Text(
                        "₹4,200",
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
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
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
                              backgroundColor: primaryColor.withOpacity(.15),
                              child: Text(
                                "A",
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
                                    "Amit Patel",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  const Text(
                                    "9876543210",
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
                                    color: Colors.green.withOpacity(.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Get ₹0",
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
                                    color: Colors.red.withOpacity(.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Give ₹1,500",
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
        ],
      ),
    );
  }
}
