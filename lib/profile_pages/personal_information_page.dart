import 'package:fin_track/profile_pages/edit_information_page.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  final Color themeColor = const Color(0xFF8BC24A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUserSession();
    });
  }

  Widget infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: themeColor.withValues(alpha: 0.15),
            child: Icon(icon, color: themeColor),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isNotEmpty ? value : "Not Entered",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final name = userProvider.name;
        final phone = userProvider.phoneNumber;
        final email = userProvider.email;
        final address = userProvider.address;
        final isLoading = userProvider.isLoading;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text(
              "Personal Information",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
          ),
          body: (isLoading)
              ? Center(child: CircularProgressIndicator(color: themeColor))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      infoTile(
                        icon: Icons.person_outline,
                        title: "Full Name",
                        value: name,
                      ),
                      infoTile(
                        icon: Icons.phone_outlined,
                        title: "Mobile Number",
                        value: phone,
                      ),
                      infoTile(
                        icon: Icons.email_outlined,
                        title: "Email Address",
                        value: email,
                      ),
                      infoTile(
                        icon: Icons.location_on_outlined,
                        title: "Address",
                        value: address,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditInformationPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text(
                            "Edit Information",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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
      },
    );
  }
}
