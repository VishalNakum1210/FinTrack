import 'package:fin_track/utils/category_theme.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:flutter/material.dart';

/// Bank-grade transaction tile displaying metadata, mode pills, and post-transaction balance.
class PassbookTransactionTile extends StatelessWidget {
  final String category;
  final String description;
  final String paymentMode;
  final String time;
  final double amount;
  final bool isIncome;
  final double? runningBalance;
  final String? splitFriendName;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const PassbookTransactionTile({
    super.key,
    required this.category,
    required this.description,
    required this.paymentMode,
    required this.time,
    required this.amount,
    required this.isIncome,
    this.runningBalance,
    this.splitFriendName,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = CategoryTheme.getBgColor(category);
    final iconColor = CategoryTheme.getColor(category);
    final icon = CategoryTheme.getIcon(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 44dp Category Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Payment mode pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CategoryTheme.getMethodIcon(paymentMode),
                                  size: 11,
                                  color: const Color(0xFF475569),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  paymentMode,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Split Badge (if split)
                          if (splitFriendName != null && splitFriendName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Split with $splitFriendName 👥",
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6D28D9),
                                ),
                              ),
                            ),

                          // Time
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Amount & Running Balance Column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isIncome ? "+${amount.toINR()}" : "-${amount.toINR()}",
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: isIncome ? const Color(0xFF2E7D32) : const Color(0xFF1E293B),
                      ),
                    ),
                    if (runningBalance != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Bal: ${runningBalance!.toINR()}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (onEdit != null) ...[
                      const SizedBox(height: 5),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onEdit,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF8BC24A).withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 11,
                                  color: Color(0xFF2E7D32),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  "Edit",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
