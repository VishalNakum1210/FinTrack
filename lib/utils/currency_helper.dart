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
  static String format(num value, {bool showDecimals = false, bool compactSymbol = false}) {
    if (compactSymbol) {
      return _compactInr.format(value);
    }
    if (showDecimals || (value is double && value.truncateToDouble() != value)) {
      return _inrWithDecimals.format(value);
    }
    return _inrNoDecimals.format(value);
  }

  /// Parses a dynamic string or number safely into double
  static double parse(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final cleanStr = value.toString().replaceAll(',', '').replaceAll('₹', '').trim();
    return double.tryParse(cleanStr) ?? 0.0;
  }
}

extension CurrencyFormatting on num {
  String toINR({bool showDecimals = false, bool compactSymbol = false}) {
    return CurrencyHelper.format(this, showDecimals: showDecimals, compactSymbol: compactSymbol);
  }
}
