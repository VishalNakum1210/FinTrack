import 'package:fin_track/friends_pages/split_bill_page.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('SplitBillPage Widget Tests', () {
    late FriendProvider friendProvider;

    setUp(() {
      friendProvider = FriendProvider();
      friendProvider.setFriendsForTesting([
        {
          'friend_name': 'Aman Patel',
          'friend_number': '8888888888',
          'total_get': 500,
          'total_give': 0,
        },
        {
          'friend_name': 'Rahul Sharma',
          'friend_number': '7777777777',
          'total_get': 0,
          'total_give': 300,
        },
      ]);
    });

    Widget createWidgetUnderTest() {
      return ChangeNotifierProvider<FriendProvider>.value(
        value: friendProvider,
        child: const MaterialApp(
          home: SplitBillPage(),
        ),
      );
    }

    testWidgets('renders top header and navigation tabs', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Split Bill & Group Trips'), findsOneWidget);
      expect(find.text('⚡ Single Bill'), findsOneWidget);
      expect(find.text('🏖️ Group Trip (Multi-Split)'), findsOneWidget);
    });

    testWidgets('renders Single Bill tab fields by default', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Total Bill Amount'), findsOneWidget);
      expect(find.text('Bill Information'), findsOneWidget);
      expect(find.text('Who Paid the Bill?'), findsOneWidget);
      expect(find.text('Split with Friends'), findsOneWidget);
      expect(find.text('Aman Patel'), findsAtLeastNWidgets(1));
      expect(find.text('Rahul Sharma'), findsAtLeastNWidgets(1));
    });

    testWidgets('switching to Group Trip tab displays trip info and expenses',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Tap Group Trip tab
      await tester.tap(find.text('🏖️ Group Trip (Multi-Split)'));
      await tester.pumpAndSettle();

      expect(find.text('Trip / Event Information'), findsOneWidget);
      expect(find.text('Trip Members'), findsOneWidget);
      expect(find.text('Trip Expenses'), findsAtLeastNWidgets(1));
      expect(find.text('Add Bill'), findsOneWidget);
      expect(find.text('No expenses added yet'), findsOneWidget);
    });

    testWidgets('opening Add Bill modal in Group Trip displays multi-payer options',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Switch to Group Trip
      await tester.tap(find.text('🏖️ Group Trip (Multi-Split)'));
      await tester.pumpAndSettle();

      // Select Aman Patel to be in the trip
      await tester.tap(find.text('Aman Patel'));
      await tester.pumpAndSettle();

      // Tap Add Bill
      await tester.tap(find.text('Add Bill'));
      await tester.pumpAndSettle();

      // Verify bottom sheet modal opened
      expect(find.text('Add Expense to Trip'), findsOneWidget);
      expect(find.text('Who Paid the Bill?'), findsOneWidget);
      expect(find.text('Split Between Who?'), findsOneWidget);
      expect(find.text('Add to Trip'), findsOneWidget);
    });

    testWidgets(
        'changing who paid the bill automatically updates split selection and unselects previous payer',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final amanCheckboxFinder =
          find.widgetWithText(CheckboxListTile, 'Aman Patel');
      final rahulCheckboxFinder =
          find.widgetWithText(CheckboxListTile, 'Rahul Sharma');

      expect(
          tester.widget<CheckboxListTile>(amanCheckboxFinder).value, isFalse);
      expect(
          tester.widget<CheckboxListTile>(rahulCheckboxFinder).value, isFalse);

      // Select Aman Patel as payer
      final amanChoiceChip = find.widgetWithText(ChoiceChip, 'Aman Patel');
      await tester.ensureVisible(amanChoiceChip);
      await tester.tap(amanChoiceChip);
      await tester.pumpAndSettle();

      // Aman should now be checked, Rahul still unchecked
      await tester.ensureVisible(amanCheckboxFinder);
      expect(tester.widget<CheckboxListTile>(amanCheckboxFinder).value, isTrue);
      expect(
          tester.widget<CheckboxListTile>(rahulCheckboxFinder).value, isFalse);

      // Change payer to Rahul Sharma
      final rahulChoiceChip = find.widgetWithText(ChoiceChip, 'Rahul Sharma');
      await tester.ensureVisible(rahulChoiceChip);
      await tester.tap(rahulChoiceChip);
      await tester.pumpAndSettle();

      // Aman should be deselected (removed), Rahul should be selected
      await tester.ensureVisible(amanCheckboxFinder);
      expect(
          tester.widget<CheckboxListTile>(amanCheckboxFinder).value, isFalse);
      expect(tester.widget<CheckboxListTile>(rahulCheckboxFinder).value, isTrue);

      // Switch payer back to You (I Paid)
      final meChoiceChip = find.widgetWithText(ChoiceChip, 'You (I Paid)');
      await tester.ensureVisible(meChoiceChip);
      await tester.tap(meChoiceChip);
      await tester.pumpAndSettle();

      // Rahul should now be deselected
      await tester.ensureVisible(rahulCheckboxFinder);
      expect(
          tester.widget<CheckboxListTile>(rahulCheckboxFinder).value, isFalse);
    });
  });
}
