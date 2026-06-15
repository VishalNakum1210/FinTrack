import 'package:account/user_pages/main_page.dart';
import 'package:account/user_pages/profile.dart';
import 'package:flutter/material.dart';

class NavPageSelector extends StatefulWidget {
  @override
  State<NavPageSelector> createState() => _navPageSelector();
}

class _navPageSelector extends State<NavPageSelector> {
  int selectedIndex = 0;

  final List<Widget> pages = [
    UserMainPage(),
    Container(color: Colors.amber),
    Container(color: Colors.red),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: Colors.green.shade100,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,

        onDestinationSelected: (int index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          // Home
          // NavigationDestination(
          //   icon: Icon(Icons.home_outlined),
          //   selectedIcon: Icon(Icons.home_rounded),
          //   label: "Home",
          // ),

          // // Passbook / Transactions
          // NavigationDestination(
          //   icon: Icon(Icons.receipt_long_outlined),
          //   selectedIcon: Icon(Icons.receipt_long_rounded),
          //   label: "Passbook",
          // ),

          // // Add People
          // NavigationDestination(
          //   icon: Icon(Icons.person_add_alt_outlined),
          //   selectedIcon: Icon(Icons.person_add_alt_1_rounded),
          //   label: "Add",
          // ),

          // // Profile
          // NavigationDestination(
          //   icon: Icon(Icons.account_circle_outlined),
          //   selectedIcon: Icon(Icons.account_circle_rounded),
          //   label: "Profile",
          // ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: "Home",
          ),

          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: "Passbook",
          ),

          NavigationDestination(
            icon: Icon(Icons.group_add_outlined),
            selectedIcon: Icon(Icons.group_add),
            label: "Add Friends",
          ),

          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
