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

  final TextEditingController feedbackController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  String selectedType = "Suggestion";
  int rating = 0;
  bool isLoading = false;

  Future<void> submitFeedback() async {
    if (feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter feedback"),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences sp =
          await SharedPreferences.getInstance();

      String phoneNumber =
          sp.getString("phone_number") ?? "";

      DatabaseReference ref = FirebaseDatabase.instance.ref(
        "userUpdates/$phoneNumber",
      );

      await ref.push().set({
        "rating": rating,
        "type": selectedType,
        "message": feedbackController.text.trim(),
        "email": emailController.text.trim(),
        "phone_number": phoneNumber,
        "timestamp": ServerValue.timestamp,
      });

      feedbackController.clear();
      emailController.clear();

      setState(() {
        rating = 0;
        selectedType = "Suggestion";
      });

      Fluttertoast.showToast(
        msg: "Thank you for your feedback ❤️",
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error : $e",
      );
    }

    setState(() {
      isLoading = false;
    });
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
        color: index < rating
            ? Colors.amber
            : Colors.grey.shade300,
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
        borderSide: BorderSide(
          color: themeColor.withOpacity(0.25),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: themeColor,
          width: 2,
        ),
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
                  colors: [
                    themeColor,
                    themeColor.withOpacity(0.75),
                  ],
                ),
              ),
              child: Column(
                children: const [
                  Icon(
                    Icons.feedback_rounded,
                    color: Colors.white,
                    size: 55,
                  ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
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
                    color:
                        themeColor.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Rate Your Experience",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => buildStar(index),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Feedback Type",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration:
                        inputDecoration("Select Type"),
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
                        value: "Other",
                        child: Text("Other"),
                      ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: feedbackController,
                    maxLines: 6,
                    decoration: inputDecoration(
                      "Write your feedback here...",
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Email (Optional)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextField(
                    controller: emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration: inputDecoration(
                      "example@gmail.com",
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
                onPressed:
                    isLoading ? null : submitFeedback,
                icon: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  isLoading
                      ? "Submitting..."
                      : "Submit Feedback",
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
                    borderRadius:
                        BorderRadius.circular(18),
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

  @override
  void dispose() {
    feedbackController.dispose();
    emailController.dispose();
    super.dispose();
  }
}