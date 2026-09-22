import 'package:fin_track/profile_pages/report_page.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExpenseProvider expenseProvider;
  late FriendProvider friendProvider;
  late UserProvider userProvider;

  final now = DateTime.now();
  final currentMonthStr =
      "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

  final mockRecords = [
    {
      'key': 'rec-1',
      'Amount': '50000',
      'Category': 'Salary',
      'Date': currentMonthStr,
      'Description': 'Monthly salary',
      'Payment_Mode': 'Add Online',
      'timestamp': now.millisecondsSinceEpoch,
    },
    {
      'key': 'rec-2',
      'Amount': '12000',
      'Category': 'Food & Drinks',
      'Date': currentMonthStr,
      'Description': 'Groceries & restaurant',
      'Payment_Mode': 'Spent Online',
      'timestamp': now.millisecondsSinceEpoch,
    },
    {
      'key': 'rec-3',
      'Amount': '3000',
      'Category': 'Travel',
      'Date': currentMonthStr,
      'Description': 'Cab fares',
      'Payment_Mode': 'Spent Cash',
      'timestamp': now.millisecondsSinceEpoch,
    },
  ];

  setUp(() {
    expenseProvider = ExpenseProvider();
    expenseProvider.setRecordsForTesting(mockRecords);

    friendProvider = FriendProvider();
    friendProvider.setFriendsForTesting([], totalGet: 0, totalGive: 0);

    userProvider = UserProvider();
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ExpenseProvider>.value(value: expenseProvider),
        ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: const MaterialApp(
        home: Reportpage(),
      ),
    );
  }

  group('Reportpage Suite 6 UI Layout Tests', () {
    testWidgets('renders all Suite 6 financial report components', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 1. AppBar
      expect(find.text("Financial Reports"), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);

      // 2. Period Selector Tabs
      expect(find.text("This Month"), findsOneWidget);
      expect(find.text("Last Month"), findsOneWidget);
      expect(find.text("This Year"), findsOneWidget);

      // 3. Financial Health Score Card
      expect(find.text("Financial Health Score Card"), findsOneWidget);
      expect(find.textContaining("Good"), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // 4. Cash Flow Overview Card
      expect(find.text("Cash Flow Overview Card"), findsOneWidget);
      expect(find.text("Total Income:"), findsOneWidget);
      expect(find.text("Total Expense:"), findsOneWidget);
      expect(find.text("Savings rate"), findsOneWidget);

      // 5. Spending by Category Card
      expect(find.text("Spending by Category Card"), findsOneWidget);
      expect(find.text("Food & Drinks"), findsOneWidget);
      expect(find.text("Travel"), findsOneWidget);

      // 6. Payment Mode Split
      expect(find.text("Payment Mode Split Card"), findsOneWidget);
      expect(find.text("Cash:"), findsOneWidget);
      expect(find.text("Online:"), findsOneWidget);

      // 7. Visual Breakdown Accordion Toggle
      expect(find.text("Visual Charts & Analysis"), findsOneWidget);

      // 8. Bottom CTA Button
      expect(find.text("Export PDF Report"), findsOneWidget);
    });

    testWidgets('opens health score explanation sheet on info tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap info icon
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text("Health Score Formula"), findsOneWidget);
      expect(find.text("Score = (Income - Expense) / Income × 100"), findsOneWidget);
    });

    testWidgets('switching period segment tabs updates selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap Last Month
      await tester.tap(find.text("Last Month"));
      await tester.pumpAndSettle();

      // Tap This Year
      await tester.tap(find.text("This Year"));
      await tester.pumpAndSettle();

      // Return to This Month
      await tester.tap(find.text("This Month"));
      await tester.pumpAndSettle();

      expect(find.text("This Month"), findsOneWidget);
    });

    testWidgets('toggles collapsible visual charts section', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap Visual Charts & Analysis to expand
      final chartsToggle = find.text("Visual Charts & Analysis");
      await tester.ensureVisible(chartsToggle);
      await tester.tap(chartsToggle);
      await tester.pumpAndSettle();

      expect(find.text("Cashflow Comparison"), findsOneWidget);
      expect(find.text("Expense Distribution Donut"), findsOneWidget);

      // Tap again to collapse
      await tester.tap(chartsToggle);
      await tester.pumpAndSettle();

      expect(find.text("Cashflow Comparison"), findsNothing);
    });
  });
}
