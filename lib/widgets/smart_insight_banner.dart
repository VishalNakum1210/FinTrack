import 'package:flutter/material.dart';

/// Contextual financial insight callout card.
class SmartInsightBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onDismiss;

  const SmartInsightBanner({
    super.key,
    required this.message,
    this.icon = Icons.lightbulb_outline_rounded,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEDC8)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF558B2F)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF33691E),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.close, size: 16, color: Color(0xFF689F38)),
              ),
            ),
        ],
      ),
    );
  }
}
