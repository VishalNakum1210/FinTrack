import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddFriends extends StatefulWidget {
  @override
  State<AddFriends> createState() => _addFriendPage();
}

class _addFriendPage extends State<AddFriends> {
  TextEditingController cname = TextEditingController();
  TextEditingController cphone_number = TextEditingController();
  TextEditingController cnote = TextEditingController();

  void setFriendDetails() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    String userPhone_number = sp.getString("phone_number")!;
    String name = cname.text,
        phone_number = cphone_number.text,
        note = cnote.text;
    if (name.isNotEmpty && phone_number.isNotEmpty && note.isNotEmpty) {
      try {
        DatabaseReference myref = FirebaseDatabase.instance.ref(
          "Friends/$userPhone_number",
        );
        DateTime now = DateTime.now();
        await myref.child(phone_number).set({
          "friend_name": name,
          "friend_number": phone_number,
          "note": note,
          "date" : DateFormat('dd/MM/yyyy').format(now),
          "timestamp" : ServerValue.timestamp,
          "total_get" : "0",
          "total_give" : "0",
          "Records" : null
        });

        Fluttertoast.showToast(msg: "Friend details add Successfully");
        Navigator.pop(context, true);

      } catch (e) {
        Fluttertoast.showToast(msg: "Not connected $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Add Friend Details",
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
                height: 350,
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),

                child: Container(
                  child: Column(
                    children: [
                      Container(
                        margin: EdgeInsets.only(right: 20, left: 20, top: 20),
                        child: TextField(
                          controller: cname,
                          decoration: InputDecoration(
                            hintText: "Friend Name",
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
                          controller: cphone_number,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: "Friend Phone Number",
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
                          controller: cnote,
                          decoration: InputDecoration(
                            hintText: "Note",
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
                        height: 50,
                        margin: EdgeInsets.only(left: 40, right: 40, top: 30),
                        child: ElevatedButton(
                          onPressed: () {
                            // getAllDetails();
                            setFriendDetails();
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
        ],
      ),
    );
  }
}
