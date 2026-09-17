import 'dart:convert';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final Color themeColor = const Color(0xFF8BC24A);

  final TextEditingController feedbackController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String selectedType = "Suggestion";
  int rating = 0;
  bool isLoading = false;
  DateTime? _lastSubmitTime;

  @override
  void initState() {
    super.initState();
    _syncPendingFeedback();
  }

  Future<void> _syncPendingFeedback() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final pending = sp.getStringList('pending_feedback');
      if (pending != null && pending.isNotEmpty) {
        final phoneNumber = await SessionManager.getPhoneNumber() ?? "";
        if (phoneNumber.isNotEmpty) {
          final ref = FirebaseDatabase.instance.ref("userUpdates/$phoneNumber");
          for (final item in List<String>.from(pending)) {
            final data = jsonDecode(item) as Map<String, dynamic>;
            await ref.push().set({
              ...data,
              "synced_at": ServerValue.timestamp,
            });
          }
          await sp.remove('pending_feedback');
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    feedbackController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void _showThankYouDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_rounded, color: Colors.pink, size: 55),
            const SizedBox(height: 12),
            const Text(
              "Thank You!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Your feedback helps make FinTrack better for everyone.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Done"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> submitFeedback() async {
    final message = feedbackController.text.trim();
    if (message.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter feedback");
      return;
    }

    final email = emailController.text.trim();
    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
      if (!emailRegex.hasMatch(email)) {
        Fluttertoast.showToast(msg: "Please enter a valid email address");
        return;
      }
    }

    if (_lastSubmitTime != null && DateTime.now().difference(_lastSubmitTime!).inSeconds < 10) {
      Fluttertoast.showToast(msg: "Please wait 10 seconds before submitting feedback again.");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      String phoneNumber = await SessionManager.getPhoneNumber() ?? "";
      if (phoneNumber.isEmpty) {
        Fluttertoast.showToast(msg: "Session expired. Please log in again.");
        if (mounted) setState(() => isLoading = false);
        return;
      }

      DatabaseReference ref = FirebaseDatabase.instance.ref(
        "userUpdates/$phoneNumber",
      );

      await ref.push().set({
        "rating": rating,
        "type": selectedType,
        "message": message,
        "email": email,
        "timestamp": ServerValue.timestamp,
      }).timeout(const Duration(seconds: 6));

      feedbackController.clear();
      emailController.clear();
      _lastSubmitTime = DateTime.now();

      setState(() {
        rating = 0;
        selectedType = "Suggestion";
      });

      if (mounted) {
        _showThankYouDialog();
      }
    } catch (e) {
      // Offline fallback: Queue locally in SharedPreferences
      try {
        final sp = await SharedPreferences.getInstance();
        final list = sp.getStringList('pending_feedback') ?? [];
        list.add(jsonEncode({
          "rating": rating,
          "type": selectedType,
          "message": message,
          "email": email,
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        }));
        await sp.setStringList('pending_feedback', list);

        feedbackController.clear();
        emailController.clear();
        setState(() {
          rating = 0;
          selectedType = "Suggestion";
        });
        Fluttertoast.showToast(msg: "Saved offline. Will sync when connected.");
        if (mounted) _showThankYouDialog();
      } catch (_) {
        Fluttertoast.showToast(msg: "Failed to submit feedback: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget buildStar(int index) {
    return IconButton(
      onPressed: () {
        setState(() {
          rating = index + 1;
        });
      },
      icon: Icon(
        Icons.star_rounded,
        size: 38,
        color: index < rating ? Colors.amber : Colors.grey.shade300,
      ),
    );
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: themeColor.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: themeColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF2),
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: const Text(
          "Feedback & Suggestions",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [themeColor, themeColor.withValues(alpha: 0.75)],
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.feedback_rounded, color: Colors.white, size: 55),
                  SizedBox(height: 12),
                  Text(
                    "We Value Your Feedback",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Help us improve the app by sharing your suggestions and experiences.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Rate Your Experience",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) => buildStar(index)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Feedback Type",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: inputDecoration("Select Type"),
                    items: const [
                      DropdownMenuItem(
                        value: "Suggestion",
                        child: Text("Suggestion"),
                      ),
                      DropdownMenuItem(
                        value: "Bug Report",
                        child: Text("Bug Report"),
                      ),
                      DropdownMenuItem(
                        value: "Feature Request",
                        child: Text("Feature Request"),
                      ),
                      DropdownMenuItem(
                        value: "Complaint",
                        child: Text("Complaint"),
                      ),
                      DropdownMenuItem(
                        value: "General Feedback",
                        child: Text("General Feedback"),
                      ),
                      DropdownMenuItem(value: "Other", child: Text("Other")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Your Feedback",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: feedbackController,
                    maxLines: 6,
                    maxLength: 1000,
                    decoration: inputDecoration("Write your feedback here...").copyWith(counterText: ""),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Email (Optional)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    maxLength: 100,
                    decoration: inputDecoration("example@gmail.com").copyWith(counterText: ""),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : submitFeedback,
                icon: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  isLoading ? "Submitting..." : "Submit Feedback",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
