import 'package:FinTrack/GetInformation/GetUserDetail.dart';
import 'package:FinTrack/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditInformationPage extends StatefulWidget {
  const EditInformationPage({super.key});

  @override
  State<EditInformationPage> createState() => _EditInformationPageState();
}

class _EditInformationPageState extends State<EditInformationPage> {
  final Color themeColor = const Color(0xFF8BC24A);
  Map<String, String> details = {};

  TextEditingController nameController = TextEditingController(text: "User");

  TextEditingController mobileController = TextEditingController(
    text: "9876543210",
  );

  TextEditingController emailController = TextEditingController(
    text: "user@gmail.com",
  );

  TextEditingController addressController = TextEditingController(
    text: "User Address",
  );

  Widget customField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),

          floatingLabelStyle: TextStyle(
            color: themeColor,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, color: themeColor),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: themeColor, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> updateInformation(
    String name,
    String phoneNumber,
    String email,
    String address,
  ) async {
    try {
      await context.read<UserProvider>().updateProfile(
        name: name,
        email: email,
        address: address,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to update profile: $e");
    }
  }

  void getDetails() async {
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();
      String phoneNumber = sp.getString("phone_number") ?? "";
      if (phoneNumber.isNotEmpty) {
        details = await getUserInformation(phoneNumber);
        if (mounted) {
          setState(() {
            nameController.text = details["name"] ?? "";
            mobileController.text = details["phone_number"] ?? phoneNumber;
            emailController.text = details["email"] ?? "";
            addressController.text = details["address"] ?? details["Address"] ?? "";
          });
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Edit Information"),
        centerTitle: true,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: themeColor,
              child: const Icon(Icons.person, size: 65, color: Colors.white),
            ),

            const SizedBox(height: 25),

            customField(
              label: "Full Name",
              icon: Icons.person_outline,
              controller: nameController,
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: TextField(
                controller: mobileController,
                readOnly: true,
                style: TextStyle(color: Colors.grey.shade700),
                decoration: InputDecoration(
                  labelText: "Mobile Number (Cannot be changed)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),

            customField(
              label: "Email",
              icon: Icons.email_outlined,
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
            ),

            customField(
              label: "Address",
              icon: Icons.location_on_outlined,
              controller: addressController,
              maxLines: 3,
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () async {
                  String name = nameController.text.trim();
                  String mobile = mobileController.text.trim();
                  String email = emailController.text.trim();
                  String address = addressController.text.trim();

                  if (name.isEmpty || email.isEmpty) {
                    Fluttertoast.showToast(msg: "Name and Email cannot be empty");
                    return;
                  }

                  await updateInformation(name, mobile, email, address);

                  Fluttertoast.showToast(
                    msg: "Information Updated Successfully",
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.save),
                label: const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
