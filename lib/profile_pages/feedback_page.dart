import 'dart:async';
import 'dart:convert';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _darkGreen = Color(0xFF2E7D32);
  static const Color _canvasBg = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderGrey = Color(0xFFE2E8F0);

  final TextEditingController feedbackController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String selectedType = "Suggestion";
  int rating = 0;
  bool isLoading = false;
  DateTime? _lastSubmitTime;

  final List<Map<String, dynamic>> _feedbackTypes = const [
    {"label": "Suggestion", "icon": Icons.lightbulb_rounded},
    {"label": "Bug Report", "icon": Icons.bug_report_rounded},
    {"label": "Feature Request", "icon": Icons.auto_awesome_rounded},
    {"label": "Complaint", "icon": Icons.warning_amber_rounded},
    {"label": "General Feedback", "icon": Icons.chat_bubble_outline_rounded},
    {"label": "Other", "icon": Icons.more_horiz_rounded},
  ];

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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: _darkGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Thank You!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your feedback helps make FinTrack better for everyone. We appreciate your thoughts!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textMuted,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Done",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> submitFeedback() async {
    final message = feedbackController.text.trim();
    if (message.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter your feedback message");
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

    if (_lastSubmitTime != null &&
        DateTime.now().difference(_lastSubmitTime!).inSeconds < 10) {
      Fluttertoast.showToast(
        msg: "Please wait 10 seconds before submitting feedback again.",
      );
      return;
    }

    bool isOffline = false;
    try {
      isOffline = context.read<FriendProvider>().isOffline;
    } catch (_) {}

    setState(() {
      isLoading = true;
    });

    try {
      // 1. Resolve phone number with Auth verification
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Fluttertoast.showToast(msg: "Please log in to submit feedback.");
        if (mounted) setState(() => isLoading = false);
        return;
      }

      String phoneNumber = "";
      if (currentUser.email != null && currentUser.email!.endsWith('@fintrack.app')) {
        phoneNumber = currentUser.email!.split('@').first.trim();
      }
      if (phoneNumber.isEmpty) {
        phoneNumber = await SessionManager.getPhoneNumber() ?? "";
      }
      phoneNumber = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (phoneNumber.length > 10) {
        phoneNumber = phoneNumber.substring(phoneNumber.length - 10);
      }

      if (phoneNumber.isEmpty) {
        Fluttertoast.showToast(msg: "Session expired. Please log in again.");
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final ref = FirebaseDatabase.instance.ref(
        "userUpdates/$phoneNumber",
      );

      final payload = {
        "rating": rating,
        "type": selectedType,
        "message": message,
        "email": email,
        "timestamp": ServerValue.timestamp,
      };

      // 2. Dispatch payload based on connectivity state

      if (isOffline) {
        // Device is offline: dispatch to Firebase RTDB disk persistence
        // Firebase RTDB automatically stores this locally and syncs when reconnected
        ref.push().set(payload);
        Fluttertoast.showToast(msg: "Feedback saved offline. Will sync when reconnected.");
      } else {
        // Device is online: allow generous 15s window for cellular connection/handshake
        try {
          await ref.push().set(payload).timeout(const Duration(seconds: 15));
        } on TimeoutException {
          // If cellular latency exceeds 15s, Firebase RTDB's disk persistence
          // has already stored the write locally and will complete sync in background.
          // Do not treat as an error or show false offline messages.
        }
      }

      feedbackController.clear();
      emailController.clear();
      _lastSubmitTime = DateTime.now();

      if (mounted) {
        setState(() {
          rating = 0;
          selectedType = "Suggestion";
        });
        _showThankYouDialog();
      }
    } on FirebaseException catch (fe) {
      Fluttertoast.showToast(msg: "Submission failed: ${fe.message ?? fe.code}");
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to submit feedback. Please try again.");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildStar(int index) {
    final isSelected = index < rating;
    return GestureDetector(
      onTap: () {
        setState(() {
          rating = index + 1;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedScale(
          scale: isSelected ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Icon(
            isSelected ? Icons.star_rounded : Icons.star_border_rounded,
            size: 38,
            color: isSelected ? const Color(0xFFFFB300) : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  String _getRatingText(int stars) {
    switch (stars) {
      case 1:
        return "Needs Improvement";
      case 2:
        return "Fair Experience";
      case 3:
        return "Good";
      case 4:
        return "Very Good!";
      case 5:
        return "Excellent! 🌟";
      default:
        return "Tap to rate";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvasBg,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Feedback & Support",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borderGrey),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8F5E9),
                        border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: _darkGreen,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "We Value Your Voice",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Share feedback or report an issue. Your input guides our next updates.",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. Star Rating Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderGrey),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "Rate Your FinTrack Experience",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => _buildStar(i)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getRatingText(rating),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: rating > 0 ? const Color(0xFFD97706) : _textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Section Title
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  "FEEDBACK DETAILS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // Form Input Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderGrey),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Feedback Type
                    const Text(
                      "Category",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderGrey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _primaryGreen, width: 1.8),
                        ),
                      ),
                      dropdownColor: Colors.white,
                      items: _feedbackTypes.map((item) {
                        return DropdownMenuItem<String>(
                          value: item["label"] as String,
                          child: Row(
                            children: [
                              Icon(
                                item["icon"] as IconData,
                                size: 18,
                                color: _primaryGreen,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item["label"] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _textDark,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => selectedType = val);
                        }
                      },
                    ),

                    const SizedBox(height: 18),

                    // Feedback Message
                    const Text(
                      "Your Message",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: feedbackController,
                      maxLines: 5,
                      maxLength: 1000,
                      style: const TextStyle(fontSize: 14.5, color: _textDark),
                      decoration: InputDecoration(
                        hintText: "Tell us what happened, or share ideas for improvement...",
                        hintStyle: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderGrey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _primaryGreen, width: 1.8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Email (Optional)
                    const Text(
                      "Contact Email (Optional)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 100,
                      style: const TextStyle(fontSize: 14.5, color: _textDark),
                      decoration: InputDecoration(
                        hintText: "your.email@example.com (for follow-up)",
                        hintStyle: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.mail_outline_rounded,
                          color: _primaryGreen,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderGrey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _borderGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _primaryGreen, width: 1.8),
                        ),
                        counterText: "",
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Primary CTA: Submit Feedback Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : submitFeedback,
                  icon: isLoading
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send_rounded, size: 18),
                  label: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Submit Feedback",
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
