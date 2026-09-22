import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/widgets/edit_expense_modal.dart';
import 'package:fin_track/widgets/passbook_transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MockExpenseProvider extends ChangeNotifier implements ExpenseProvider {
  bool updateCalled = false;
  String? updatedAmount;
  String? updatedCategory;

  @override
  Future<bool> updateExpense({
    required String phoneNumber,
    required String key,
    required String amount,
    required String category,
    required String paymentMode,
    required String description,
    required String date,
  }) async {
    updateCalled = true;
    updatedAmount = amount;
    updatedCategory = category;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('EditExpenseModal & PassbookTransactionTile Edit Tests', () {
    final mockRecord = {
      'key': '-test123',
      'Amount': '750.00',
      'Category': 'Food',
      'Date': '15/09/2026',
      'Description': 'Dinner with friends',
      'Payment_Mode': 'Spent Online',
      'timestamp': 1789430400000,
    };

    testWidgets('renders all fields pre-filled from record', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showEditExpenseModal(context: context, record: mockRecord);
                  },
                  child: const Text('Open Edit Modal'),
                );
              },
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Edit Modal'));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.text('Update amount, category or payment mode'), findsOneWidget);

      // Verify Pre-filled Amount
      expect(find.text('750.00'), findsOneWidget);

      // Verify Categories are present
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);

      // Verify Payment Modes are present
      expect(find.text('Spent Online'), findsWidgets);
      expect(find.text('Spent Cash'), findsOneWidget);

      // Verify Description is pre-filled
      expect(find.text('Dinner with friends'), findsOneWidget);

      // Verify Save button
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('allows selecting different category and payment mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showEditExpenseModal(context: context, record: mockRecord);
                  },
                  child: const Text('Open Edit Modal'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Edit Modal'));
      await tester.pumpAndSettle();

      // Tap 'Shopping' category
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();

      // Tap 'Spent Cash' mode
      await tester.tap(find.text('Spent Cash'));
      await tester.pumpAndSettle();

      // Enter new amount
      final amountField = find.widgetWithText(TextField, '750.00');
      await tester.enterText(amountField, '999');
      await tester.pumpAndSettle();

      expect(find.text('999'), findsOneWidget);
    });

    testWidgets('PassbookTransactionTile displays Edit pill and fires onEdit callback', (tester) async {
      bool editTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassbookTransactionTile(
              category: 'Food',
              description: 'Dinner',
              paymentMode: 'Spent Online',
              time: '15 Sep 2026',
              amount: 750,
              isIncome: false,
              runningBalance: 5000,
              onTap: () {},
              onEdit: () {
                editTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify Edit pill is rendered
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // Tap Edit pill
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(editTapped, isTrue);
    });

    testWidgets('PassbookTransactionTile does not display Edit pill when onEdit is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PassbookTransactionTile(
              category: 'Food',
              description: 'Dinner',
              paymentMode: 'Spent Online',
              time: '15 Sep 2026',
              amount: 750,
              isIncome: false,
              runningBalance: 5000,
              onTap: () {},
              onEdit: null,
            ),
          ),
        ),
      );

      // Verify Edit pill is NOT rendered
      expect(find.text('Edit'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });
}
