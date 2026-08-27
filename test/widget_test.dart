import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('FinTrack Formatting Tests', () {
    test('Indian currency formatting', () {
      final formatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );

      expect(formatter.format(1000), equals('₹1,000'));
      expect(formatter.format(100000), equals('₹1,00,000'));
    });

    test('Date parsing and formatting', () {
      final inputDate = DateFormat('d/M/yyyy').parse('25/8/2026');
      final output = DateFormat('d MMM yyyy').format(inputDate);
      expect(output, equals('25 Aug 2026'));
    });
  });
}
