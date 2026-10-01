import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fin_track/friends_pages/split_bill_page.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/services/minimum_version_policy.dart';
import 'package:fin_track/services/split_integrity.dart';
import 'package:fin_track/utils/date_helper.dart';
import 'package:fin_track/utils/input_validator.dart';
import 'package:fin_track/utils/ledger_totals.dart';
import 'package:fin_track/utils/money.dart';
import 'package:fin_track/widgets/edit_expense_modal.dart';

void main() {
  test('CSV escapes dangerous prefixes without changing ordinary text', () {
    for (final value in [
      '\t=1+1',
      ' =1+1',
      '\r=1+1',
      '\n=1+1',
      '=1+1',
      '+1',
      '@SUM(1)',
      '-1',
      '＝1+1',
    ]) {
      final csv = ExportService.generateCsvString(
        expenses: [
          {'Amount': '1', 'Description': value},
        ],
      );
      expect(csv, contains('"\'$value"'), reason: value);
    }
    for (final value in ['normal purchase', 'rent', 'transport', 'safe text']) {
      final csv = ExportService.generateCsvString(
        expenses: [
          {'Amount': '1', 'Description': value},
        ],
      );
      expect(csv, contains('"$value"'));
      expect(csv, isNot(contains('"\'$value"')));
    }
  });

  test('large legal records retain totals and the largest category', () {
    final normalized = LedgerTotals.normalize({
      'Records': {
        'a': {'Amount': '600000000000.00', 'Type': 'Give Money To Friend'},
        'b': {'Amount': '600000000000.00', 'Type': 'Give Money To Friend'},
      },
    });
    expect(normalized['_getPaise'], 120000000000000);
    expect(normalized['total_get'], 1200000000000.0);
    expect(Money.tryAggregatePaise(normalized['total_get']), 120000000000000);
    expect(Money.sum([1200000000000.0, 1]), 1200000000001.0);
    final expenses = ExpenseProvider();
    addTearDown(expenses.dispose);
    expenses.setRecordsForTesting([
      {
        'Amount': '600000000000.00',
        'Category': 'Food',
        'Payment_Mode': 'Spent Cash',
      },
      {
        'Amount': '600000000000.00',
        'Category': 'Food',
        'Payment_Mode': 'Spent Cash',
      },
    ]);
    expect(expenses.totalExpense, 1200000000000.0);
    expect(expenses.biggestCategory, 'Food');
    expect(expenses.biggestCategoryAmount, 1200000000000.0);
  });

  test(
    'unsupported aggregate values fail explicitly, never silently reset',
    () {
      expect(Money.tryPaise('1000000000000'), isNull);
      expect(Money.tryAggregatePaise('1000000000000'), 100000000000000);
      expect(Money.tryAggregatePaise('90071992547409.92'), isNull);
      expect(() => Money.sum(['90071992547409.91', '0.01']), throwsRangeError);
    },
  );

  test('valid ISO offsets survive UTC calendar boundary conversion', () {
    for (final date in [
      '2026-09-30T23:30:00-05:00',
      '2026-10-01T00:30:00+05:30',
    ]) {
      expect(DateHelper.parse(date), DateTime.parse(date));
    }
    expect(DateHelper.parse('2026-02-30T00:00:00-05:00'), isNull);
    expect(InputValidator.dateFields('30/9/2026'), {
      'date_year': 2026,
      'date_month': 9,
      'date_day': 30,
      'date_epoch': DateTime.utc(2026, 9, 30).millisecondsSinceEpoch,
    });
  });

  test(
    'linked split deletion includes all expenses/debts but not unrelated records',
    () {
      const id = '01234567890123456789', phone = '9876543210';
      final expenses = {
        '${id}_expense_0': {'split_id': id},
        '${id}_expense_1': {'split_id': id},
        'unrelated': {'Amount': '5'},
      };
      final friends = {
        '9876500000': {
          'Records': {
            '${id}_debt_0': {'split_id': id},
            'unrelated': {'Amount': '6'},
          },
        },
      };
      final paths = SplitIntegrity.linkedPaths(
        phone,
        '${id}_expense_0',
        expenses,
        friends,
      );
      expect(
        paths,
        unorderedEquals([
          'Expenses/$phone/${id}_expense_0',
          'Expenses/$phone/${id}_expense_1',
          'Friends/$phone/9876500000/Records/${id}_debt_0',
        ]),
      );
      expect(
        SplitIntegrity.linkedPaths(phone, 'unrelated', {'unrelated': {}}, {}),
        isEmpty,
      );
    },
  );

  test(
    'legacy split key relationships are retained without relying on descriptions',
    () {
      const id = '01234567890123456789', phone = '9876543210';
      final paths = SplitIntegrity.linkedPaths(
        phone,
        '${id}_0',
        {id: {}},
        {
          '9876500000': {
            'Records': {'${id}_0': {}},
          },
        },
      );
      expect(paths.length, 2);
    },
  );

  test(
    'minimum-version refresh failure enforces the verified cached policy',
    () async {
      final minimum = await MinimumVersionPolicy.resolve(
        remote: () async => throw StateError('Offline'),
        cached: () async => '2.3.0',
        cache: (_) async {},
      );
      expect(MinimumVersionPolicy.isLower('2.2.0', minimum), isTrue);
      expect(MinimumVersionPolicy.isLower('2.3.0', minimum), isFalse);
    },
  );

  test(
    'missing cached policy never silently bypasses a failed version check',
    () async {
      await expectLater(
        MinimumVersionPolicy.resolve(
          remote: () async => throw StateError('Offline'),
          cached: () async => null,
          cache: (_) async {},
        ),
        throwsStateError,
      );
    },
  );

  test(
    'local policy-cache failure does not discard a successful remote check',
    () async {
      expect(
        await MinimumVersionPolicy.resolve(
          remote: () async => '2.3.0',
          cached: () async => null,
          cache: (_) async => throw StateError('Storage unavailable'),
        ),
        '2.3.0',
      );
    },
  );

  testWidgets('legacy debt mode stays owed when opened for editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditExpenseModalContent(
            record: {
              'key': 'id',
              'Amount': '10.00',
              'Description': 'Legacy debt',
              'Category': 'Food',
              'Payment_Mode': 'Owed to Friend',
              'Date': '30/9/2026',
            },
          ),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Owed')).style?.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.widget<Text>(find.text('Spent Online')).style?.fontWeight,
      FontWeight.w500,
    );
  });

  testWidgets('split form and confirmation fit a small phone with large text', (
    tester,
  ) async {
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalHandler?.call(details);
    };
    addTearDown(() {
      FlutterError.onError = originalHandler;
    });
    final friends = FriendProvider();
    addTearDown(friends.dispose);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<FriendProvider>.value(
        value: friends,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const SplitBillPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final dynamic state = tester.state(find.byType(SplitBillPage));
    state.amountController.text = '100';
    state.descriptionController.text = 'Lunch';
    state.selectedFriendNumbers.add('9876500000');
    unawaited(state.handleSplitBill() as Future<void>);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Confirm Bill Split'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
  });

  testWidgets('group-trip save uses the existing selected payment mode', (
    tester,
  ) async {
    final friends = FriendProvider();
    addTearDown(friends.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<FriendProvider>.value(
        value: friends,
        child: const MaterialApp(home: SplitBillPage()),
      ),
    );
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(SplitBillPage));
    state.selectedMode = 'Spent Cash';
    await tester.tap(find.text('🏖️ Group Trip (Multi-Split)'));
    await tester.pumpAndSettle();
    expect(find.text('Spent Cash'), findsOneWidget);
    expect(find.text('Paid Via'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
