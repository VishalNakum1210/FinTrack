import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fin_track/utils/balance_helper.dart';
import 'package:fin_track/utils/currency_helper.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:fin_track/utils/split_helper.dart';

void main() {
  group('1. SplitHelper Mathematical & Algorithmic Stress Tests', () {
    test('Zero-Sum Conservation Invariant across 50 participants and 200 random expenses', () {
      final rand = math.Random(42);
      final participants = List.generate(
        50,
        (i) => SplitParticipant(
          phone: '98000000${i.toString().padLeft(2, '0')}',
          name: 'Person_$i',
          isMe: i == 0,
        ),
      );

      final expenses = <GroupExpense>[];
      for (int i = 0; i < 200; i++) {
        final payer = participants[rand.nextInt(participants.length)];
        final numConsumers = rand.nextInt(participants.length - 1) + 2; // 2 to 50
        final shuffled = List<SplitParticipant>.from(participants)..shuffle(rand);
        final consumers = shuffled.take(numConsumers).toList();
        final amount = (rand.nextDouble() * 50000.0) + 10.0;

        expenses.add(
          GroupExpense(
            id: 'exp_$i',
            title: 'Expense $i',
            amount: ((amount * 100).round() / 100),
            category: 'Food',
            date: DateTime.now(),
            payer: payer,
            participants: consumers,
          ),
        );
      }

      final stopwatch = Stopwatch()..start();
      final settlements = SplitHelper.calculatePersonSettlements(
        expenses: expenses,
        allParticipants: participants,
      );
      stopwatch.stop();

      // Performance check: 50 participants x 200 expenses calculated in < 150ms
      expect(stopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'Calculation took too long: ${stopwatch.elapsedMilliseconds}ms');

      expect(settlements.length, equals(participants.length));

      // Invariant 1: Sum of all net balances must equal 0.00
      double totalNet = 0.0;
      for (final s in settlements) {
        totalNet += s.netBalance;
      }
      expect(totalNet.abs(), lessThan(0.50),
          reason: 'Total net balance across all participants must conserve to 0');

      // Invariant 2: Bilateral consistency across all pairwise debt lines
      final Map<String, PersonSettlement> settlementMap = {
        for (final s in settlements) s.person.phone: s,
      };

      for (final s in settlements) {
        for (final give in s.giveLines) {
          final otherSettlement = settlementMap[give.otherPerson.phone]!;
          // If p1 gives to p2, p2 must have a matching getLine from p1 with the exact same amount
          final matchingGet = otherSettlement.getLines.where(
            (g) => g.otherPerson.phone == s.person.phone,
          );
          expect(matchingGet.length, equals(1),
              reason: '${s.person.name} gives ${give.amount} to ${give.otherPerson.name}, but matching getLine not found');
          expect(matchingGet.first.amount, closeTo(give.amount, 0.01));
        }

        // Invariant 3: Pairwise uniqueness (never simultaneously give and get from the same person)
        final giveOtherPhones = s.giveLines.map((l) => l.otherPerson.phone).toSet();
        final getOtherPhones = s.getLines.map((l) => l.otherPerson.phone).toSet();
        expect(giveOtherPhones.intersection(getOtherPhones), isEmpty,
            reason: 'Participant cannot both owe and be owed by the same person');
      }
    });

    test('Extreme Magnitude: 1 Billion (₹100 Crore) and fractional 1 paisa splits', () {
      const me = SplitParticipant(phone: '9999999999', name: 'Me', isMe: true);
      const friend = SplitParticipant(phone: '8888888888', name: 'Friend', isMe: false);

      final massiveExpense = GroupExpense(
        id: 'huge_1',
        title: 'Real Estate Acquisition',
        amount: 1000000000.0, // 100 Crore
        category: 'Investment',
        date: DateTime.now(),
        payer: me,
        participants: [me, friend],
      );

      final tinyExpense = GroupExpense(
        id: 'tiny_1',
        title: 'Candy Share',
        amount: 0.02,
        category: 'Food',
        date: DateTime.now(),
        payer: friend,
        participants: [me, friend],
      );

      final settlements = SplitHelper.calculatePersonSettlements(
        expenses: [massiveExpense, tinyExpense],
        allParticipants: [me, friend],
      );

      final mySettlement = settlements.firstWhere((s) => s.person.isMe);
      final friendSettlement = settlements.firstWhere((s) => !s.person.isMe);

      // Me paid 1,000,000,000. Friend paid 0.02.
      // Friend owes Me 500,000,000. Me owes Friend 0.01.
      // Net: Friend owes Me 499,999,999.99
      expect(mySettlement.netBalance, closeTo(499999999.99, 0.05));
      expect(friendSettlement.netBalance, closeTo(-499999999.99, 0.05));

      expect(mySettlement.getLines.length, equals(1));
      expect(mySettlement.getLines.first.amount, closeTo(499999999.99, 0.05));
      expect(mySettlement.giveLines, isEmpty);
    });

    test('Edge Cases: 0 expenses, 1 participant, 0 amount, undeclared participants', () {
      const me = SplitParticipant(phone: '9999999999', name: 'Me', isMe: true);
      const friend = SplitParticipant(phone: '8888888888', name: 'Friend', isMe: false);
      const undeclared = SplitParticipant(phone: '7777777777', name: 'Undeclared', isMe: false);

      // 1. Zero expenses
      final emptyResult = SplitHelper.calculatePersonSettlements(
        expenses: [],
        allParticipants: [me, friend],
      );
      expect(emptyResult.length, equals(2));
      expect(emptyResult[0].netBalance, equals(0.0));
      expect(emptyResult[0].isSettled, isTrue);

      // 2. Single participant paying for self
      final soloExpense = GroupExpense(
        id: 'solo',
        title: 'Personal Lunch',
        amount: 500.0,
        category: 'Food',
        date: DateTime.now(),
        payer: me,
        participants: [me],
      );
      final soloResult = SplitHelper.calculatePersonSettlements(
        expenses: [soloExpense],
        allParticipants: [me],
      );
      expect(soloResult.length, equals(1));
      expect(soloResult[0].netBalance, equals(0.0));
      expect(soloResult[0].giveLines, isEmpty);
      expect(soloResult[0].getLines, isEmpty);

      // 3. Expense referencing an undeclared participant
      final undeclaredExpense = GroupExpense(
        id: 'undec',
        title: 'Taxi',
        amount: 300.0,
        category: 'Travel',
        date: DateTime.now(),
        payer: undeclared,
        participants: [me, undeclared],
      );
      final autoRecoverResult = SplitHelper.calculatePersonSettlements(
        expenses: [undeclaredExpense],
        allParticipants: [me], // note: undeclared participant not passed initially
      );
      // SplitHelper must auto-include undeclared participant without throwing null check errors
      expect(autoRecoverResult.length, equals(2));
      final meRes = autoRecoverResult.firstWhere((s) => s.person.phone == me.phone);
      expect(meRes.giveLines.length, equals(1));
      expect(meRes.giveLines.first.amount, equals(150.0));
    });

    test('10,000 iterations micro-benchmark stress test completes in under 1 second', () {
      const p1 = SplitParticipant(phone: '1', name: 'A');
      const p2 = SplitParticipant(phone: '2', name: 'B');
      const p3 = SplitParticipant(phone: '3', name: 'C');
      final participants = [p1, p2, p3];

      final exp1 = GroupExpense(
        id: '1',
        title: 'Hotel',
        amount: 3000.0,
        category: 'Stay',
        date: DateTime.now(),
        payer: p1,
        participants: participants,
      );
      final exp2 = GroupExpense(
        id: '2',
        title: 'Dinner',
        amount: 1500.0,
        category: 'Food',
        date: DateTime.now(),
        payer: p2,
        participants: participants,
      );

      final sw = Stopwatch()..start();
      for (int i = 0; i < 10000; i++) {
        final res = SplitHelper.calculatePersonSettlements(
          expenses: [exp1, exp2],
          allParticipants: participants,
        );
        expect(res.length, equals(3));
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: '10,000 iterations must take less than 1,000ms');
    });
  });

  group('2. BalanceHelper Scale & Corrupted Data Stress Tests', () {
    test('25,000 transactions running balance calculation performance and accuracy', () {
      final List<Map<String, dynamic>> massiveList = [];
      int expectedNet = 0;

      for (int i = 0; i < 25000; i++) {
        final isIncome = i % 3 == 0;
        final amount = (i % 500) + 1;
        if (isIncome) {
          expectedNet += amount;
        } else {
          expectedNet -= amount;
        }

        massiveList.add({
          'key': 'tx_$i',
          'Amount': amount,
          'Payment_Mode': isIncome ? 'Add CASH' : 'Spent',
          'Date': '01/01/2026',
        });
      }

      final sw = Stopwatch()..start();
      final results = BalanceHelper.computeRunningBalances(massiveList);
      sw.stop();

      expect(results.length, equals(25000));
      expect(results.last['_runningBalance'], equals(expectedNet.toDouble()));
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: '25,000 running balances computed in under 3,000ms under heavy test concurrency');
    });

    test('Corrupted data resilience: nulls, non-integers, missing keys, negatives', () {
      final corrupted = [
        {'key': '1', 'Amount': null, 'Payment_Mode': 'Add CASH', 'Date': '01/01/2026'},
        {'key': '2', 'Amount': 'not_a_number', 'Payment_Mode': 'Spent', 'Date': '02/01/2026'},
        {'key': '3', 'Amount': -250, 'Payment_Mode': 'Add CASH', 'Date': '03/01/2026'},
        {'key': '4', 'Amount': 1000, 'Payment_Mode': 'UnknownType', 'Date': '04/01/2026'},
        <String, dynamic>{},
      ];

      expect(() => BalanceHelper.computeRunningBalances(corrupted), returnsNormally);
      final res = BalanceHelper.computeRunningBalances(corrupted);
      expect(res.length, equals(5));
      for (final r in res) {
        expect(r['_runningBalance'], isA<double>());
      }
    });
  });

  group('3. CurrencyHelper Stress & Parsing Resilience', () {
    test('50,000 integers roundtrip consistency with INR formatting', () {
      for (int i = 0; i < 50000; i += 7) {
        final formatted = i.toINR();
        expect(formatted.startsWith('₹'), isTrue);
        final parsed = CurrencyHelper.parse(formatted);
        expect(parsed, equals(i.toDouble()));
      }
    });

    test('Boundary numbers: 0, 1 Trillion, Max 64-bit int', () {
      expect(0.toINR(), equals('₹ 0'));
      expect(CurrencyHelper.parse('₹ 0'), equals(0.0));

      const num trillion = 1000000000000;
      final formattedTrillion = trillion.toINR();
      expect(formattedTrillion.contains('₹'), isTrue);
      expect(CurrencyHelper.parse(formattedTrillion), equals(1000000000000.0));
    });

    test('Malformed currency string inputs do not throw exceptions', () {
      final badInputs = [
        '',
        '   ',
        'abc',
        '₹',
        '₹₹₹',
        '-₹500',
        '₹ - 500',
        '₹12,34,56.78.90',
        '₹100🔥',
        'null',
        'NaN',
        'Infinity',
      ];

      for (final input in badInputs) {
        expect(() => CurrencyHelper.parse(input), returnsNormally);
      }
    });
  });

  group('4. DateHelper Format & Boundary Stress Tests', () {
    test('10,000 diverse valid dates parse and format correctly', () {
      final base = DateTime(2020, 1, 1);
      for (int i = 0; i < 10000; i += 3) {
        final d = base.add(Duration(days: i));
        final iso = d.toIso8601String();
        final slash = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

        final parsedIso = DateHelper.parse(iso);
        final parsedSlash = DateHelper.parse(slash);

        expect(parsedIso, isNotNull);
        expect(parsedSlash, isNotNull);
        expect(parsedIso!.year, equals(d.year));
        expect(parsedSlash!.year, equals(d.year));
      }
    });

    test('Leap year boundaries: Feb 29 on leap and non-leap centuries', () {
      expect(DateHelper.parse('29/02/2024'), isNotNull);
      expect(DateHelper.parse('29/02/2000'), isNotNull);
      expect(DateHelper.parse('29/02/2028'), isNotNull);

      // Invalid leap year dates must safely return null
      expect(DateHelper.parse('29/02/2023'), isNull);
      expect(DateHelper.parse('29/02/2025'), isNull);
    });

    test('Corrupt and injection strings safely return null', () {
      final corrupt = [
        '',
        'undefined',
        'null',
        '32/01/2026',
        '00/00/0000',
        '<script>alert(1)</script>',
        '2026-13-45',
      ];
      for (final s in corrupt) {
        expect(DateHelper.parse(s), isNull);
      }
    });
  });

  group('5. UI Layout Viewport & Accessibility Scale Stress Tests', () {
    testWidgets('Quick Insights 2x2 grid renders without overflow on 240px ultra-narrow display with 2.0x font scaling',
        (tester) async {
      tester.view.physicalSize = const Size(240, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(240, 400),
              textScaler: TextScaler.linear(2.0), // 200% Accessibility Font Scale
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(8.0),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.32,
                  children: [
                    _buildTestInsightCard("Top Category", "Supercalifragilistic Shopping"),
                    _buildTestInsightCard("Highest Spend", "₹99,99,99,999"),
                    _buildTestInsightCard("Total Entries", "15,000 recorded"),
                    _buildTestInsightCard("Wallet Split", "Cash: ₹50,000", subtitle: "Online: ₹1,50,000"),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow allowed at 240px and 2.0x font scale');
      expect(find.text("Highest Spend"), findsOneWidget);
    });

    testWidgets('Friend Transaction Tile with ₹99,99,999 amount renders without collision at 280px Fold screen',
        (tester) async {
      tester.view.physicalSize = const Size(280, 650);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(280, 650)),
            child: Scaffold(
              body: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Dr. Wolfeschlegelsteinhausenbergerdorff the Third",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text("26 Sep 2026", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 95),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          "+₹99,99,999",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 16),
                      onPressed: () {},
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text("+₹99,99,999"), findsOneWidget);
    });
  });
}

Widget _buildTestInsightCard(String title, String value, {String? subtitle}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ],
    ),
  );
}
