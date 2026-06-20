import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackPage extends StatefulWidget {
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
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
      SharedPreferences sp = await SharedPreferences.getInstance();
      String phoneNumber = sp.getString("phone_number")!;
      DatabaseReference ref = FirebaseDatabase.instance.ref(
        "userUpdates/${phoneNumber}",
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
      Fluttertoast.showToast(msg: "Thank you for your feedback ❤️");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error : $e");
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
        size: 36,
        color: index < rating
            ? Colors.amber
            : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FA),
      appBar: AppBar(
        title: const Text("Feedback & Suggestions"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff16A34A),
                    Color(0xff22C55E),
                  ],
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.feedback,
                    color: Colors.white,
                    size: 50,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "We value your feedback",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Help us improve the app by sharing your thoughts.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

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
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),
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
              decoration: InputDecoration(
                hintText:
                    "Write your feedback here...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
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
              decoration: InputDecoration(
                hintText: "example@gmail.com",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed:
                    isLoading ? null : submitFeedback,
                icon: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  isLoading
                      ? "Submitting..."
                      : "Submit Feedback",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xff16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15),
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