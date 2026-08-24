import 'package:FinTrack/user_pages/PassbookPage.dart';
import 'package:FinTrack/FriendsPages/friend_expenses.dart';
import 'package:FinTrack/user_pages/main_page.dart';
import 'package:FinTrack/user_pages/profile.dart';
import 'package:flutter/material.dart';

class NavPageSelector extends StatefulWidget {
  const NavPageSelector({super.key});

  @override
  State<NavPageSelector> createState() => _NavPageSelectorState();
}

class _NavPageSelectorState extends State<NavPageSelector> {
  int selectedIndex = 0;

  final List<Widget> _pages = const [
    UserMainPage(),
    PassbookApp(),
    FriendPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),
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
