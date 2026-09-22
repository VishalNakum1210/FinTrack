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
  static const Color _primaryGreen = Color(0xFF8BC24A);
  static const Color _canvasBg = Color(0xFFF8FAFC);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderGrey = Color(0xFFE2E8F0);

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

    String currentName = userProvider.name;
    if (currentName.isEmpty || currentName == "User") {
      final sessionUsername = await SessionManager.getUsername();
      if (sessionUsername != null &&
          sessionUsername.trim().isNotEmpty &&
          sessionUsername.trim() != "User") {
        currentName = sessionUsername.trim();
      }
    }

    if (currentName.isNotEmpty && currentName != "User") {
      _originalName = currentName;
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
          String resolvedName = "";
          for (final k in [
            'name',
            'Name',
            'username',
            'userName',
            'fullName',
            'FullName',
            'displayName'
          ]) {
            final val = details[k]?.trim();
            if (val != null && val.isNotEmpty && val != 'User') {
              resolvedName = val;
              break;
            }
          }
          if (resolvedName.isEmpty) {
            resolvedName = await SessionManager.getUsername() ?? "";
          }
          _originalName = resolvedName == "User" ? "" : resolvedName;
          _originalEmail = details["email"] ?? details["Email"] ?? "";
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
          "Edit Information",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryGreen),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Centered Avatar with Camera Badge
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE8F5E9),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryGreen.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _originalName.isNotEmpty
                                  ? _originalName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E293B),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Full Name Field (14px Rounded Borders)
                  _buildLabeledField(
                    label: "Full Name",
                    child: TextField(
                      controller: nameController,
                      maxLength: 50,
                      decoration: _inputDecoration(
                        prefixIcon: Icons.person_outline_rounded,
                        hintText: "Enter full name",
                      ),
                    ),
                  ),

                  // 3. Mobile Number Field (Read-only, 14px Rounded Borders)
                  _buildLabeledField(
                    label: "Mobile Number",
                    child: TextField(
                      controller: mobileController,
                      readOnly: true,
                      style: const TextStyle(
                        color: _textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: _inputDecoration(
                        prefixIcon: Icons.lock_outline_rounded,
                        hintText: "Mobile number",
                        isReadOnly: true,
                      ),
                    ),
                  ),

                  // 4. Email Field (14px Rounded Borders)
                  _buildLabeledField(
                    label: "Email",
                    child: TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 100,
                      decoration: _inputDecoration(
                        prefixIcon: Icons.mail_outline_rounded,
                        hintText: "Enter email address",
                      ),
                    ),
                  ),

                  // 5. Residential Address Field (3 lines, 14px Rounded Borders)
                  _buildLabeledField(
                    label: "Residential Address",
                    child: TextField(
                      controller: addressController,
                      minLines: 3,
                      maxLines: 4,
                      maxLength: 200,
                      decoration: _inputDecoration(
                        prefixIcon: Icons.location_on_outlined,
                        hintText: "Enter residential address",
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 6. Bottom CTA Button (52px Elevated Button)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        disabledBackgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.grey.shade500,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (!_isDirty || isSaving) ? null : _handleSave,
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required IconData prefixIcon,
    required String hintText,
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      counterText: "",
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(
        prefixIcon,
        color: isReadOnly ? _textMuted : const Color(0xFF64748B),
        size: 20,
      ),
      filled: true,
      fillColor: isReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isReadOnly ? _borderGrey : const Color(0xFFCBD5E1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryGreen, width: 1.8),
      ),
    );
  }

  Future<void> _handleSave() async {
    final name = nameController.text.trim();
    final mobile = mobileController.text.trim();
    final email = emailController.text.trim();
    final address = addressController.text.trim();

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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully"),
          backgroundColor: _primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } else {
      Fluttertoast.showToast(msg: "Failed to update profile");
    }
  }
}
