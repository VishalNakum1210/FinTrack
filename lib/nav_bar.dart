import 'dart:math' as math;
import 'package:fin_track/friends_pages/friend_expenses.dart';
import 'package:fin_track/user_pages/main_page.dart';
import 'package:fin_track/user_pages/passbook_page.dart';
import 'package:fin_track/user_pages/profile.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class NavPageSelector extends StatefulWidget {
  const NavPageSelector({super.key});

  @override
  State<NavPageSelector> createState() => _NavPageSelectorState();
}

class _NavPageSelectorState extends State<NavPageSelector> {
  int selectedIndex = 0;

  static const Color _activeGreen = Color(0xFF2E7D32);
  static const Color _pillBackground = Color(0xFFDCEDC8);
  static const Color _pillBorder = Color(0xFFA5D6A7);
  static const Color _inactiveGrey = Color(0xFF64748B);
  static const Color _borderGrey = Color(0xFFE2E8F0);

  final List<Widget> _pages = const [
    UserMainPage(),
    PassbookApp(),
    FriendPage(),
    ProfilePage(),
  ];

  final List<_NavItemData> _navItems = const [
    _NavItemData(
      label: "Home",
      outlinedIcon: Icons.home_outlined,
      filledIcon: Icons.home_rounded,
    ),
    _NavItemData(
      label: "Passbook",
      outlinedIcon: Icons.book_outlined,
      filledIcon: Icons.book_rounded,
    ),
    _NavItemData(
      label: "Friends",
      outlinedIcon: Icons.people_outline_rounded,
      filledIcon: Icons.people_rounded,
    ),
    _NavItemData(
      label: "Profile",
      outlinedIcon: Icons.person_outline_rounded,
      filledIcon: Icons.person_rounded,
    ),
  ];

  void _onTabTapped(int index) {
    if (index != selectedIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        selectedIndex = index;
      });
    }
  }

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
        body: Consumer<FriendProvider>(
          builder: (context, friendProvider, child) {
            final isOffline = friendProvider.isOffline;
            return Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: isOffline ? 36.0 : 0.0,
                  child: isOffline
                      ? Container(
                          width: double.infinity,
                          color: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 8),
                              Text(
                                "No Internet Connection • Offline Mode",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(child: child!),
              ],
            );
          },
          child: IndexedStack(
            index: selectedIndex,
            children: _pages,
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: _borderGrey, width: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 12,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final tabWidth = totalWidth / _navItems.length;
                  final double pillWidth = math.min(74.0, tabWidth - 6);
                  const double pillHeight = 52.0;
                  final double pillLeft =
                      (selectedIndex * tabWidth) + ((tabWidth - pillWidth) / 2);

                  return Stack(
                    children: [
                      // 1. Sliding Mint Capsule Pill Indicator (Encloses Icon & Label)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                        left: pillLeft,
                        top: 8,
                        width: pillWidth,
                        height: pillHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _pillBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _pillBorder.withValues(alpha: 0.6),
                              width: 0.9,
                            ),
                          ),
                        ),
                      ),

                      // 2. Interactive Tab Items
                      Row(
                        children: List.generate(_navItems.length, (index) {
                          final item = _navItems[index];
                          final bool isSelected = index == selectedIndex;

                          return Expanded(
                            child: InkWell(
                              onTap: () => _onTabTapped(index),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: SizedBox(
                                height: 68,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Animated Icon with Scale Effect
                                    SizedBox(
                                      height: 32,
                                      child: Center(
                                        child: AnimatedScale(
                                          scale: isSelected ? 1.08 : 1.0,
                                          duration: const Duration(milliseconds: 200),
                                          child: Icon(
                                            isSelected
                                                ? item.filledIcon
                                                : item.outlinedIcon,
                                            size: 22,
                                            color: isSelected
                                                ? _activeGreen
                                                : _inactiveGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),

                                    // Animated Typography Label
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? _activeGreen
                                            : _inactiveGrey,
                                        letterSpacing: isSelected ? -0.2 : 0,
                                      ),
                                      child: Text(item.label),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;

  const _NavItemData({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
  });
}
