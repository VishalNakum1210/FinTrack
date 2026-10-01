import 'package:intl/intl.dart';

class CurrencyHelper {
  static final NumberFormat _inrNoDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 0,
  );

  static final NumberFormat _inrWithDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  static final NumberFormat _compactInr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats any numeric value into standard Indian Currency (e.g. ₹ 1,500)
  static String format(
    num value, {
    bool showDecimals = false,
    bool compactSymbol = false,
  }) {
    if (compactSymbol) {
      return (value % 1 == 0
              ? _compactInr
              : NumberFormat.currency(
                  locale: 'en_IN',
                  symbol: '₹',
                  decimalDigits: 2,
                ))
          .format(value);
    }
    if (showDecimals ||
        (value is double && value.truncateToDouble() != value)) {
      return _inrWithDecimals.format(value);
    }
    return _inrNoDecimals.format(value);
  }

  /// Compact Indian format (e.g. ₹1.50L, ₹2.30Cr, ₹4.50K)
  static String compact(num value) {
    final absVal = value.abs();
    final sign = value < 0 ? '-' : '';
    if (absVal >= 10000000) {
      return '$sign₹${(absVal / 10000000).toStringAsFixed(2)}Cr';
    } else if (absVal >= 100000) {
      return '$sign₹${(absVal / 100000).toStringAsFixed(2)}L';
    } else if (absVal >= 1000) {
      return '$sign₹${(absVal / 1000).toStringAsFixed(2)}K';
    }
    return format(value);
  }

  /// Formats with explicit sign (+₹500 / -₹500)
  static String formatSigned(num value) {
    if (value > 0) return '+${format(value)}';
    if (value < 0) return '-${format(value.abs())}';
    return format(value);
  }

  /// Parses a dynamic string or number safely into double
  static double parse(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.isFinite ? value.toDouble() : 0.0;
    final cleanStr = value
        .toString()
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .trim();
    final parsed = double.tryParse(cleanStr);
    return parsed != null && parsed.isFinite ? parsed : 0.0;
  }
}

extension CurrencyFormatting on num {
  String toINR({bool showDecimals = false, bool compactSymbol = false}) {
    return CurrencyHelper.format(
      this,
      showDecimals: showDecimals,
      compactSymbol: compactSymbol,
    );
  }

  String toCompactINR() {
    return CurrencyHelper.compact(this);
  }

  String toSignedINR() {
    return CurrencyHelper.formatSigned(this);
  }
}
