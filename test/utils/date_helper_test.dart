import 'package:fin_track/utils/date_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateHelper', () {
    test('parses slash-formatted dates correctly', () {
      final dt = DateHelper.parse('25/8/2026');
      expect(dt, isNotNull);
      expect(dt!.day, equals(25));
      expect(dt.month, equals(8));
      expect(dt.year, equals(2026));
    });

    test('parses ISO format correctly', () {
      final dt = DateHelper.parse('2026-08-25');
      expect(dt, isNotNull);
      expect(dt!.day, equals(25));
      expect(dt.month, equals(8));
      expect(dt.year, equals(2026));
    });

    test('parses dash d-m-yyyy format correctly', () {
      final dt = DateHelper.parse('25-08-2026');
      expect(dt, isNotNull);
      expect(dt!.day, equals(25));
      expect(dt.month, equals(8));
      expect(dt.year, equals(2026));
    });

    test('returns null for empty or invalid values', () {
      expect(DateHelper.parse(null), isNull);
      expect(DateHelper.parse(''), isNull);
      expect(DateHelper.parse('-'), isNull);
      expect(DateHelper.parse('invalid_string'), isNull);
    });

    test('formats display date correctly', () {
      expect(DateHelper.formatDisplay('25/8/2026'), equals('25 Aug 2026'));
      expect(DateHelper.formatDisplay(null), equals(''));
    });
  });
}
