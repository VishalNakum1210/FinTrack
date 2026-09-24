import 'package:fin_track/utils/balance_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BalanceHelper Tests', () {
    test('returns empty list when input is empty', () {
      final result = BalanceHelper.computeRunningBalances([]);
      expect(result, isEmpty);
    });

    test('computes running balance correctly across mixed income and expenses', () {
      final records = [
        {
          'Amount': '500',
          'Date': '10/01/2026',
          'Payment_Mode': 'Add Online',
          'timestamp': 1000,
        },
        {
          'Amount': '200',
          'Date': '12/01/2026',
          'Payment_Mode': 'Spent Online',
          'timestamp': 1200,
        },
        {
          'Amount': '100',
          'Date': '11/01/2026',
          'Payment_Mode': 'Spent Cash',
          'timestamp': 1100,
        },
        {
          'Amount': '1000',
          'Date': '09/01/2026',
          'Payment_Mode': 'Add CASH',
          'timestamp': 900,
        },
      ];

      final result = BalanceHelper.computeRunningBalances(records);

      expect(result.length, equals(4));
      // Chronological order: 09/01 (+1000), 10/01 (+500), 11/01 (-100), 12/01 (-200)
      expect(result[0]['Date'], equals('09/01/2026'));
      expect(result[0]['_runningBalance'], equals(1000.0));

      expect(result[1]['Date'], equals('10/01/2026'));
      expect(result[1]['_runningBalance'], equals(1500.0));

      expect(result[2]['Date'], equals('11/01/2026'));
      expect(result[2]['_runningBalance'], equals(1400.0));

      expect(result[3]['Date'], equals('12/01/2026'));
      expect(result[3]['_runningBalance'], equals(1200.0));
    });
  });
}
