import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _canvasBg = Color(0xFFF8FAFC);
  static const Color _primaryText = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

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

    String userPhoneNumber = await SessionManager.getPhoneNumber() ?? "";

    if (userPhoneNumber.isEmpty) {
      final authEmail = FirebaseAuth.instance.currentUser?.email;
      if (authEmail != null && authEmail.endsWith('@fintrack.app')) {
        userPhoneNumber = authEmail.split('@').first;
      }
    }

    if (userPhoneNumber.isEmpty) {
      Fluttertoast.showToast(msg: "User session expired. Please log in again.");
      return;
    }

    final normInput = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final normUser = userPhoneNumber.replaceAll(RegExp(r'\D'), '');
    final cleanInput = normInput.length >= 10
        ? normInput.substring(normInput.length - 10)
        : normInput;
    final cleanUser = normUser.length >= 10
        ? normUser.substring(normUser.length - 10)
        : normUser;

    if (cleanInput.isNotEmpty && cleanInput == cleanUser) {
      Fluttertoast.showToast(msg: "You cannot add yourself as a friend");
      return;
    }

    if (!mounted) return;
    final existingFriends = context.read<FriendProvider>().friends;
    final isDuplicate = existingFriends.any(
      (f) => (f["friend_number"] ?? "").toString().trim() == phoneNumber,
    );
    if (isDuplicate) {
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Friend Already Exists"),
          content: Text(
            "A friend with number $phoneNumber is already in your list. Would you like to update their name and note?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Update"),
            ),
          ],
        ),
      );
      if (shouldUpdate != true) return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      DateTime now = DateTime.now();
      if (!mounted) return;
      final result = await context.read<FriendProvider>().addFriend(
        userPhone: userPhoneNumber,
        friendName: name,
        friendNumber: phoneNumber,
        note: note,
        date: DateFormat('d/M/yyyy').format(now),
      );

      if (result == AddFriendResult.added) {
        Fluttertoast.showToast(msg: "Friend added successfully");
        if (!mounted) return;
        Navigator.pop(context, true);
      } else if (result == AddFriendResult.updated) {
        Fluttertoast.showToast(msg: "Friend details updated successfully");
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        final lastErr = context.read<FriendProvider>().lastError;
        Fluttertoast.showToast(
          msg: lastErr != null && lastErr.isNotEmpty
              ? "Failed to save friend: $lastErr"
              : "Failed to save friend details",
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to save friend: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      counterText: "",
      filled: true,
      fillColor: _canvasBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.2, color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(width: 1.8, color: _primaryGreen),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBg,
      appBar: AppBar(
        title: const Text(
          "Add Friend",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _primaryGreen,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryText.withValues(alpha: 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Friend Information",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Add a friend to track loans, borrow amounts, and split bills",
                          style: TextStyle(fontSize: 13, color: _mutedText),
                        ),
                        const SizedBox(height: 22),

                        // Full Name
                        const Text(
                          "Full Name",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryText),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          maxLength: 50,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _primaryText),
                          decoration: _inputDecoration(
                            hint: "Friend's Name",
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Mobile Number
                        const Text(
                          "Mobile Number",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryText),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _primaryText),
                          decoration: _inputDecoration(
                            hint: "10 digit Number",
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 14, right: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("🇮🇳 +91", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryText)),
                                  const SizedBox(width: 8),
                                  Container(height: 18, width: 1.2, color: const Color(0xFFCBD5E1)),
                                ],
                              ),
                            ),
                            suffixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF94A3B8), size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Note
                        const Text(
                          "Note / Tag (Optional)",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _primaryText),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteController,
                          maxLength: 150,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _primaryText),
                          decoration: _inputDecoration(
                            hint: "e.g. Roommate, Colleague",
                            prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF94A3B8), size: 20),
                          ),
                        ),
                        const SizedBox(height: 26),

                        // Save Friend Button
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : setFriendDetails,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              disabledBackgroundColor: const Color(0xFFCBD5E1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Save Friend",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: _primaryGreen),
              ),
            ),
        ],
      ),
    );
  }
}
