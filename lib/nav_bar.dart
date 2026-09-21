import 'package:fin_track/user_pages/passbook_page.dart';
import 'package:fin_track/friends_pages/friend_expenses.dart';
import 'package:fin_track/user_pages/main_page.dart';
import 'package:fin_track/user_pages/profile.dart';
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
    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && selectedIndex != 0) {
          setState(() {
            selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            height: 68,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            indicatorColor: const Color(0xFFDCEDC8),
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
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: "Friends",
            ),
            NavigationDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts),
              label: "Profile",
            ),
            ],
          ),
        ),
      ),
    );
  }
}
