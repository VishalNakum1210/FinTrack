import 'package:fin_track/utils/split_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SplitHelper Tests', () {
    const userMe = SplitParticipant(phone: '9999999999', name: 'You', isMe: true);
    const friendAman = SplitParticipant(phone: '8888888888', name: 'Aman');
    const friendRahul = SplitParticipant(phone: '7777777777', name: 'Rahul');

    test('Single bill paid by Friend Aman split among 3 people', () {
      final expenses = [
        GroupExpense(
          id: 'exp1',
          title: 'Goa Dinner',
          amount: 1500,
          category: 'Food',
          date: DateTime(2026, 9, 26),
          payer: friendAman,
          participants: [userMe, friendAman, friendRahul],
        ),
      ];

      final settlements = SplitHelper.calculatePersonSettlements(
        expenses: expenses,
        allParticipants: [userMe, friendAman, friendRahul],
      );

      expect(settlements.length, equals(3));

      // Aman paid 1500, consumed 500 -> Net = +1000
      final amanSettlement = settlements.firstWhere((s) => s.person == friendAman);
      expect(amanSettlement.totalPaid, equals(1500.0));
      expect(amanSettlement.totalConsumed, equals(500.0));
      expect(amanSettlement.netBalance, equals(1000.0));
      expect(amanSettlement.willGet, isTrue);
      expect(amanSettlement.getLines.length, equals(2)); // Gets from You and Rahul

      // You paid 0, consumed 500 -> Net = -500 (Owes Aman 500)
      final meSettlement = settlements.firstWhere((s) => s.person == userMe);
      expect(meSettlement.totalPaid, equals(0.0));
      expect(meSettlement.totalConsumed, equals(500.0));
      expect(meSettlement.netBalance, equals(-500.0));
      expect(meSettlement.willGive, isTrue);
      expect(meSettlement.giveLines.length, equals(1));
      expect(meSettlement.giveLines.first.otherPerson, equals(friendAman));
      expect(meSettlement.giveLines.first.amount, equals(500.0));

      // Rahul paid 0, consumed 500 -> Net = -500 (Owes Aman 500)
      final rahulSettlement = settlements.firstWhere((s) => s.person == friendRahul);
      expect(rahulSettlement.giveLines.first.otherPerson, equals(friendAman));
      expect(rahulSettlement.giveLines.first.amount, equals(500.0));
    });

    test('3 Friends Trip: 3 different bills paid by 3 different people', () {
      // Bill 1: Dinner 1500 paid by Aman (500 each)
      // Bill 2: Train 900 paid by Rahul (300 each)
      // Bill 3: Fuel 600 paid by You (200 each)
      final expenses = [
        GroupExpense(
          id: 'exp1',
          title: 'Dinner',
          amount: 1500,
          category: 'Food',
          date: DateTime(2026, 9, 26),
          payer: friendAman,
          participants: [userMe, friendAman, friendRahul],
        ),
        GroupExpense(
          id: 'exp2',
          title: 'Train',
          amount: 900,
          category: 'Transport',
          date: DateTime(2026, 9, 27),
          payer: friendRahul,
          participants: [userMe, friendAman, friendRahul],
        ),
        GroupExpense(
          id: 'exp3',
          title: 'Fuel',
          amount: 600,
          category: 'Transport',
          date: DateTime(2026, 9, 28),
          payer: userMe,
          participants: [userMe, friendAman, friendRahul],
        ),
      ];

      final settlements = SplitHelper.calculatePersonSettlements(
        expenses: expenses,
        allParticipants: [userMe, friendAman, friendRahul],
      );

      // Verify Aman (Paid 1500, Consumed 1000, Net +500)
      final aman = settlements.firstWhere((s) => s.person == friendAman);
      expect(aman.totalPaid, equals(1500.0));
      expect(aman.totalConsumed, equals(1000.0)); // 500 + 300 + 200
      expect(aman.netBalance, equals(500.0)); // +500
      expect(aman.giveLines.isEmpty, isTrue); // Cleaned: 0 give lines
      expect(aman.getLines.length, equals(2)); // Net 200 from Rahul, Net 300 from You
      expect(aman.getLines.any((l) => l.otherPerson == friendRahul && l.amount == 200.0), isTrue);
      expect(aman.getLines.any((l) => l.otherPerson == userMe && l.amount == 300.0), isTrue);

      // Verify You (Paid 600, Consumed 1000, Net -400)
      final me = settlements.firstWhere((s) => s.person == userMe);
      expect(me.totalPaid, equals(600.0));
      expect(me.totalConsumed, equals(1000.0));
      expect(me.netBalance, equals(-400.0)); // -400
      expect(me.getLines.isEmpty, isTrue); // 0 get lines
      expect(me.giveLines.length, equals(2)); // Net 300 to Aman, Net 100 to Rahul
      expect(me.giveLines.any((l) => l.otherPerson == friendAman && l.amount == 300.0), isTrue);
      expect(me.giveLines.any((l) => l.otherPerson == friendRahul && l.amount == 100.0), isTrue);

      // Verify Rahul (Paid 900, Consumed 1000, Net -100)
      final rahul = settlements.firstWhere((s) => s.person == friendRahul);
      expect(rahul.totalPaid, equals(900.0));
      expect(rahul.totalConsumed, equals(1000.0));
      expect(rahul.netBalance, equals(-100.0)); // -100
      expect(rahul.giveLines.length, equals(1)); // Net 200 to Aman
      expect(rahul.giveLines.first.otherPerson, equals(friendAman));
      expect(rahul.giveLines.first.amount, equals(200.0));
      expect(rahul.getLines.length, equals(1)); // Net 100 from You
      expect(rahul.getLines.first.otherPerson, equals(userMe));
      expect(rahul.getLines.first.amount, equals(100.0));

      // Global conservation of money: sum of net balances is 0
      final totalNet = settlements.fold<double>(0.0, (sum, s) => sum + s.netBalance);
      expect(totalNet.abs() < 0.001, isTrue);
    });

    test('Pairwise netting: Take 500 from friend and Give 200 to friend -> Only 1 net record: Take 300', () {
      final expenses = [
        // Bill 1: You paid 1000 for You and Aman (500 each) -> Aman owes You 500
        GroupExpense(
          id: 'exp1',
          title: 'Hotel',
          amount: 1000,
          category: 'Other',
          date: DateTime(2026, 9, 26),
          payer: userMe,
          participants: [userMe, friendAman],
        ),
        // Bill 2: Aman paid 400 for You and Aman (200 each) -> You owe Aman 200
        GroupExpense(
          id: 'exp2',
          title: 'Dinner',
          amount: 400,
          category: 'Food',
          date: DateTime(2026, 9, 27),
          payer: friendAman,
          participants: [userMe, friendAman],
        ),
      ];

      final settlements = SplitHelper.calculatePersonSettlements(
        expenses: expenses,
        allParticipants: [userMe, friendAman],
      );

      final me = settlements.firstWhere((s) => s.person == userMe);
      // Net = 500 - 200 = +300
      expect(me.netBalance, equals(300.0));
      expect(me.giveLines.isEmpty, isTrue); // No give line
      expect(me.getLines.length, equals(1)); // Exactly 1 net line!
      expect(me.getLines.first.otherPerson, equals(friendAman));
      expect(me.getLines.first.amount, equals(300.0));

      final aman = settlements.firstWhere((s) => s.person == friendAman);
      // Aman owes 300
      expect(aman.netBalance, equals(-300.0));
      expect(aman.getLines.isEmpty, isTrue);
      expect(aman.giveLines.length, equals(1)); // Exactly 1 give line!
      expect(aman.giveLines.first.otherPerson, equals(userMe));
      expect(aman.giveLines.first.amount, equals(300.0));
    });

    test('Empty expenses list returns empty settlements with 0 balances', () {
      final settlements = SplitHelper.calculatePersonSettlements(
        expenses: [],
        allParticipants: [userMe, friendAman],
      );
      expect(settlements.length, equals(2));
      expect(settlements.every((s) => s.isSettled), isTrue);
    });
  });
}
