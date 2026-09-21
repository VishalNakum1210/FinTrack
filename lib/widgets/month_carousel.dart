import 'package:fin_track/utils/category_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Horizontally scrollable month selector carousel with calendar picker trigger.
class MonthCarousel extends StatelessWidget {
  final DateTime? selectedMonth;
  final ValueChanged<DateTime?> onMonthSelected;
  final VoidCallback? onCustomDateRange;

  const MonthCarousel({
    super.key,
    required this.selectedMonth,
    required this.onMonthSelected,
    this.onCustomDateRange,
  });

  static const Color primaryGreen = CategoryTheme.primaryGreen;

  List<DateTime> _generateRecentMonths() {
    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = 5; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final recentMonths = _generateRecentMonths();

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // "All Months" pill
          _buildPill(
            label: "All",
            isSelected: selectedMonth == null,
            onTap: () => onMonthSelected(null),
          ),
          const SizedBox(width: 8),

          // Month Pills
          ...recentMonths.map((dt) {
            final isSelected = selectedMonth != null &&
                selectedMonth!.year == dt.year &&
                selectedMonth!.month == dt.month;
            final label = DateFormat('MMM yyyy').format(dt);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildPill(
                label: label,
                isSelected: isSelected,
                onTap: () => onMonthSelected(dt),
              ),
            );
          }),

          // Calendar range icon button
          InkWell(
            onTap: onCustomDateRange,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 16, color: primaryGreen),
                  SizedBox(width: 4),
                  Text(
                    "Custom",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryGreen : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}
