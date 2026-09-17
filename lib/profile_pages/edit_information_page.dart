import 'package:fin_track/get_information/get_user_detail.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class EditInformationPage extends StatefulWidget {
  const EditInformationPage({super.key});

  @override
  State<EditInformationPage> createState() => _EditInformationPageState();
}

class _EditInformationPageState extends State<EditInformationPage> {
  final Color themeColor = const Color(0xFF8BC24A);
  bool isLoading = true;
  bool isSaving = false;
  bool _isDirty = false;

  String _originalName = '';
  String _originalEmail = '';
  String _originalAddress = '';

  final TextEditingController nameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  void _checkDirty() {
    final dirty = nameController.text.trim() != _originalName ||
        emailController.text.trim() != _originalEmail ||
        addressController.text.trim() != _originalAddress;
    if (dirty != _isDirty && mounted) {
      setState(() => _isDirty = dirty);
    }
  }

  Widget customField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int minLines = 1,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        decoration: InputDecoration(
          counterText: "",
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
    nameController.removeListener(_checkDirty);
    emailController.removeListener(_checkDirty);
    addressController.removeListener(_checkDirty);
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<bool> updateInformation(
    String name,
    String phoneNumber,
    String email,
    String address,
  ) async {
    try {
      return await context.read<UserProvider>().updateProfile(
        name: name,
        email: email,
        address: address,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to update profile: $e");
      return false;
    }
  }

  void _populateFromUserProvider() async {
    final userProvider = context.read<UserProvider>();
    String phone = userProvider.phoneNumber;
    if (phone.isEmpty) {
      phone = await SessionManager.getPhoneNumber() ?? "";
    }

    if (userProvider.name.isNotEmpty) {
      _originalName = userProvider.name;
      _originalEmail = userProvider.email;
      _originalAddress = userProvider.address;

      nameController.text = _originalName;
      mobileController.text = phone;
      emailController.text = _originalEmail;
      addressController.text = _originalAddress;

      setState(() => isLoading = false);
    } else {
      try {
        if (phone.isNotEmpty) {
          final details = await getUserInformation(phone);
          _originalName = details["name"] ?? "";
          _originalEmail = details["email"] ?? "";
          _originalAddress = details["address"] ?? details["Address"] ?? "";

          nameController.text = _originalName;
          mobileController.text = details["phone_number"] ?? phone;
          emailController.text = _originalEmail;
          addressController.text = _originalAddress;
        }
      } catch (_) {}
      if (mounted) setState(() => isLoading = false);
    }

    nameController.addListener(_checkDirty);
    emailController.addListener(_checkDirty);
    addressController.addListener(_checkDirty);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _populateFromUserProvider();
    });
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8BC24A)))
          : SingleChildScrollView(
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
              maxLength: 50,
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
              maxLength: 100,
            ),
            customField(
              label: "Address",
              icon: Icons.location_on_outlined,
              controller: addressController,
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: (!_isDirty || isSaving)
                    ? null
                    : () async {
                        String name = nameController.text.trim();
                        String mobile = mobileController.text.trim();
                        String email = emailController.text.trim();
                        String address = addressController.text.trim();

                        if (name.isEmpty || email.isEmpty) {
                          Fluttertoast.showToast(msg: "Name and Email cannot be empty");
                          return;
                        }

                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$');
                        if (!emailRegex.hasMatch(email)) {
                          Fluttertoast.showToast(msg: "Please enter a valid email address");
                          return;
                        }

                        setState(() => isSaving = true);
                        final success = await updateInformation(name, mobile, email, address);
                        if (mounted) setState(() => isSaving = false);

                        if (success) {
                          _originalName = name;
                          _originalEmail = email;
                          _originalAddress = address;
                          _checkDirty();

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Profile updated successfully"),
                              backgroundColor: Color(0xFF8BC24A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (context.mounted) Navigator.pop(context, true);
                        } else {
                          Fluttertoast.showToast(msg: "Failed to update profile");
                        }
                      },
                icon: isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  isSaving ? "Saving..." : "Save Changes",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.grey.shade600,
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
