import 'date_helper.dart';
import 'money.dart';

class InputValidator {
  static const modes = {
    'Spent Cash',
    'Spent Online',
    'Add CASH',
    'Add Online',
    'Owed',
  };
  static const categories = {
    'Food',
    'Shopping',
    'Transport',
    'Education',
    'HealthCare',
    'Entertainment',
    'Add Money',
    'Other',
  };
  static const friendTypes = {'Give Money To Friend', 'Take Money From Friend'};
  static bool phone(String value) => RegExp(r'^\d{10}$').hasMatch(value);
  static bool key(String value) =>
      value.isNotEmpty &&
      value.length <= 128 &&
      !RegExp(r'[.#$\[\]/\x00-\x1f\x7f]').hasMatch(value);
  static bool description(String value) =>
      value.trim().isNotEmpty && value.length <= 500;
  static bool date(String value) {
    final parsed = DateHelper.parse(value);
    final now = DateTime.now();
    return parsed != null &&
        !parsed.isBefore(DateTime(2000)) &&
        !parsed.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));
  }

  static String normalizedDate(String value) {
    final parsed = DateHelper.parse(value);
    if (parsed == null) throw ArgumentError('Invalid date');
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  /// Canonical calendar components let rules verify a Gregorian date against
  /// server time, without trusting a separate client timestamp.
  static Map<String, Object> dateFields(String value) {
    final parsed = DateHelper.parse(value);
    if (parsed == null) throw ArgumentError('Invalid date');
    return {
      'date_year': parsed.year,
      'date_month': parsed.month,
      'date_day': parsed.day,
      'date_epoch': DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
      ).millisecondsSinceEpoch,
    };
  }

  static bool mode(String value) =>
      modes.contains(value) || value.startsWith('Owed to ') || value == 'Owed';

  static bool transaction({
    required String amount,
    required String description,
    required String mode,
    required String date,
    String? category,
    String? type,
  }) =>
      Money.positive(amount) &&
      InputValidator.description(description) &&
      InputValidator.mode(mode) &&
      InputValidator.date(date) &&
      (category == null || categories.contains(category)) &&
      (type == null || friendTypes.contains(type));
}
