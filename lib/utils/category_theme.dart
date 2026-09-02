import 'package:flutter/material.dart';

class CategoryTheme {
  static const Color primaryGreen = Color(0xFF8BC24A);
  static const Color darkGreen = Color(0xFF689F38);

  /// Returns the corresponding IconData for any expense category
  static IconData getIcon(String category) {
    switch (category.trim().toLowerCase()) {
      case "shopping":
        return Icons.shopping_bag_rounded;
      case "food":
        return Icons.restaurant_rounded;
      case "transport":
        return Icons.directions_car_filled_rounded;
      case "education":
        return Icons.school_rounded;
      case "healthcare":
        return Icons.medical_services_rounded;
      case "entertainment":
        return Icons.movie_filter_rounded;
      case "add money":
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  /// Returns the primary accent Color for a category
  static Color getColor(String category) {
    switch (category.trim().toLowerCase()) {
      case "shopping":
        return Colors.deepOrange;
      case "food":
        return const Color(0xFFFF9800);
      case "transport":
        return const Color(0xFF2196F3);
      case "education":
        return const Color(0xFF3F51B5);
      case "healthcare":
        return const Color(0xFFE53935);
      case "entertainment":
        return const Color(0xFFEC407A);
      case "add money":
      case "add cash":
      case "add online":
        return const Color(0xFF43A047);
      default:
        return const Color(0xFF757575);
    }
  }

  /// Returns the pastel background Color for category icons/chips
  static Color getBgColor(String category) {
    switch (category.trim().toLowerCase()) {
      case "shopping":
        return const Color.fromARGB(39, 255, 86, 34);
      case "food":
        return const Color(0xFFFFF3E0);
      case "transport":
        return const Color(0xFFE3F2FD);
      case "education":
        return const Color(0xFFE8EAF6);
      case "healthcare":
        return const Color(0xFFFFEBEE);
      case "entertainment":
        return const Color(0xFFFCE4EC);
      case "add money":
      case "add cash":
      case "add online":
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  /// Returns the IconData for payment method modes
  static IconData getMethodIcon(String method) {
    switch (method.trim()) {
      case "Spent Cash":
        return Icons.currency_rupee_rounded;
      case "Spent Online":
        return Icons.payment_rounded;
      default:
        return Icons.add_card_rounded;
    }
  }
}
