import 'package:FinTrack/GetInformation/GetUserDetail.dart';
import 'package:FinTrack/ProfilePages/EditInformationPage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  final Color themeColor = const Color(0xFF8BC24A);
  bool isLoading = false;
  Map<String, String> details = {};

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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: themeColor.withOpacity(0.15),
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
                  value,
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

  void getDetails() async {
    setState(() {
      isLoading = true;
    });
    SharedPreferences sp = await SharedPreferences.getInstance();
    String phone_number = sp.getString("phone_number")!;
    details = await getUserInformation(phone_number);
    setState(() {
      isLoading = false;
    });
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
        title: const Text(
          "Personal Information",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      body: (isLoading)
          ? Container(
              child: Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  /// Profile Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 55,
                          backgroundColor: themeColor,
                          child: const Icon(
                            Icons.person,
                            size: 65,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          details["name"]!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  infoTile(
                    icon: Icons.person_outline,
                    title: "Full Name",
                    value: details["name"]!,
                  ),

                  infoTile(
                    icon: Icons.phone_outlined,
                    title: "Mobile Number",
                    value: details["phone_number"]!,
                  ),

                  infoTile(
                    icon: Icons.email_outlined,
                    title: "Email",
                    value: details["email"]!,
                  ),

                  infoTile(
                    icon: Icons.location_on_outlined,
                    title: "Address",
                    value: details["address"] ?? "Not Updated",
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditInformationPage(),
                          ),
                        ) ?? false;

                        if(result){
                          getDetails();
                        }
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
  }
}
