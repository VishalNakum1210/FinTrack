import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AddFriends extends StatefulWidget {
  const AddFriends({super.key});

  @override
  State<AddFriends> createState() => _AddFriendsState();
}

class _AddFriendsState extends State<AddFriends> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController noteController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> setFriendDetails() async {
    String name = nameController.text.trim();
    String phoneNumber = phoneController.text.trim();
    String note = noteController.text.trim();

    if (name.isEmpty || phoneNumber.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter friend's name and phone number");
      return;
    }

    if (phoneNumber.length != 10 || int.tryParse(phoneNumber) == null) {
      Fluttertoast.showToast(msg: "Please enter a valid 10-digit phone number");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String userPhoneNumber = await SessionManager.getPhoneNumber() ?? "";

      if (userPhoneNumber.isEmpty) {
        Fluttertoast.showToast(msg: "User not logged in");
        return;
      }

      DateTime now = DateTime.now();
      if (!mounted) return;
      final success = await context.read<FriendProvider>().addFriend(
        userPhone: userPhoneNumber,
        friendName: name,
        friendNumber: phoneNumber,
        note: note,
        date: DateFormat('dd/MM/yyyy').format(now),
      );

      if (success) {
        Fluttertoast.showToast(msg: "Friend added successfully");
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        Fluttertoast.showToast(msg: "Failed to add friend");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to add friend: $e");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF2),
      appBar: AppBar(
        title: const Text(
          "Add Friend",
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
                      "Friend Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8BC24A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      maxLength: 50,
                      decoration: inputDecoration("Friend Name"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: inputDecoration("Friend Phone Number").copyWith(counterText: ""),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLength: 150,
                      decoration: inputDecoration("Note (Optional)"),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : setFriendDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8BC24A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Save Friend",
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
