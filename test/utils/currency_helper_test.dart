import 'package:fin_track/utils/currency_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyHelper', () {
    test('formats basic numbers to INR format', () {
      expect(CurrencyHelper.format(1000), equals('₹ 1,000'));
      expect(CurrencyHelper.format(100000), equals('₹ 1,00,000'));
      expect(CurrencyHelper.format(0), equals('₹ 0'));
    });

    test('formats compact symbol when requested', () {
      expect(CurrencyHelper.format(500, compactSymbol: true), equals('₹500'));
      expect(CurrencyHelper.format(25000, compactSymbol: true), equals('₹25,000'));
    });

    test('toINR extension on num formats properly', () {
      expect(500.toINR(), equals('₹ 500'));
      expect(12500.toINR(), equals('₹ 12,500'));
      expect((-1500).toINR(), equals('-₹ 1,500'));
    });

    test('parses formatted currency strings correctly', () {
      expect(CurrencyHelper.parse('₹ 1,000'), equals(1000.0));
      expect(CurrencyHelper.parse('1,00,000'), equals(100000.0));
      expect(CurrencyHelper.parse('invalid'), equals(0.0));
    });
  });
}
