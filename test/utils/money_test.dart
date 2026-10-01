import 'dart:math';
import 'package:fin_track/utils/money.dart';
import 'package:fin_track/utils/ledger_totals.dart';
import 'package:fin_track/utils/split_helper.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'decimal amounts are exact and invalid scales/nonfinite values are rejected',
    () {
      expect(Money.paise('0.49'), 49);
      expect(Money.sum(['0.10', '0.20']), .30);
      for (final input in [
        '0.001',
        'NaN',
        'Infinity',
        '1e20',
        '',
        double.nan,
        double.infinity,
      ]) {
        expect(Money.tryPaise(input), isNull);
      }
    },
  );
  test('randomized integer-paisa splits conserve every paisa', () {
    final random = Random(42);
    for (var i = 0; i < 10000; i++) {
      final total = random.nextInt(100000000), count = 1 + random.nextInt(100);
      final shares = Money.split(total, count);
      expect(shares.fold<int>(0, (a, b) => a + b), total);
      expect(shares.reduce(max) - shares.reduce(min), lessThanOrEqualTo(1));
    }
  });
  test(
    'expense totals and categories retain paise and count owed expenses',
    () {
      final provider = ExpenseProvider();
      addTearDown(provider.dispose);
      provider.setRecordsForTesting([
        {'Amount': '0.49', 'Category': 'Food', 'Payment_Mode': 'Spent Cash'},
        {'Amount': '0.49', 'Category': 'Food', 'Payment_Mode': 'Spent Cash'},
        {'Amount': '0.01', 'Category': 'Food', 'Payment_Mode': 'Owed'},
      ]);
      expect(provider.spentCash, .98);
      expect(provider.totalExpense, .99);
      expect(provider.categoryTotals['Food'], .99);
      expect(provider.getTotalForFilter('Food'), .99);
    },
  );
  test('forged legacy ledger totals cannot change balances', () {
    final friend = LedgerTotals.normalize({
      'total_get': 999999,
      'total_give': 999999,
      'Records': {
        'a': {'Amount': '0.49', 'Type': 'Give Money To Friend'},
        'b': {'Amount': '0.49', 'Type': 'Give Money To Friend'},
        'c': {'Amount': '0.01', 'Type': 'Take Money From Friend'},
      },
    });
    expect(friend['total_get'], .98);
    expect(friend['total_give'], .01);
  });
  const me = SplitParticipant(phone: '1111111111', name: 'Me', isMe: true);
  const friend = SplitParticipant(phone: '2222222222', name: 'Friend');
  GroupExpense bill(double amount, {Map<String, double>? shares}) =>
      GroupExpense(
        id: 'r',
        title: 'Bill',
        amount: amount,
        category: 'Food',
        date: DateTime(2026, 9, 30),
        payer: me,
        participants: [me, friend],
        customShares: shares,
      );
  test(
    'one paisa debts survive settlement and equality has consistent hash codes',
    () {
      final settlements = SplitHelper.calculatePersonSettlements(
        expenses: [bill(.02)],
        allParticipants: [me, friend],
      );
      expect(settlements.first.getLines.single.amount, .01);
      expect(settlements.first.willGet, isTrue);
      const samePhone = SplitParticipant(phone: '1111111111', name: 'Alias');
      expect(me, samePhone);
      expect(me.hashCode, samePhone.hashCode);
    },
  );
  test('custom splits must cover everyone and conserve the total', () {
    for (final shares in <Map<String, double>>[
      {me.phone: .50},
      {me.phone: -.50, friend.phone: 1.50},
      {me.phone: .50, friend.phone: .49},
      {me.phone: double.nan, friend.phone: 1},
    ]) {
      expect(() => bill(1, shares: shares).validate(), throwsArgumentError);
    }
    expect(
      bill(1, shares: {me.phone: .51, friend.phone: .49}).shareFor(me),
      .51,
    );
  });
}
