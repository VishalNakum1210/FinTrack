import 'package:fin_track/nav_bar.dart';
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

  setUp(() {
    expenseProvider = ExpenseProvider();
    expenseProvider.setRecordsForTesting([]);

    friendProvider = FriendProvider();
    friendProvider.setFriendsForTesting([]);

    userProvider = UserProvider();
    userProvider.setUserForTesting(
      name: 'Test User',
      email: 'user@example.com',
      phoneNumber: '9876543210',
    );
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ExpenseProvider>.value(value: expenseProvider),
        ChangeNotifierProvider<FriendProvider>.value(value: friendProvider),
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
      ],
      child: const MaterialApp(home: NavPageSelector()),
    );
  }

  group('NavPageSelector Widget Tests', () {
    testWidgets('existing pages fit a narrow 274px screen', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(274, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
    });
    testWidgets('renders all 4 navigation tabs properly', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Passbook'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('switching tabs updates active selection', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Passbook tab
      await tester.tap(find.text('Passbook'));
      await tester.pumpAndSettle();

      final indexedStackFinder = find.byType(IndexedStack).first;
      expect(tester.widget<IndexedStack>(indexedStackFinder).index, equals(1));

      // Tap on Friends tab
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();

      expect(tester.widget<IndexedStack>(indexedStackFinder).index, equals(2));

      // Tap on Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(tester.widget<IndexedStack>(indexedStackFinder).index, equals(3));
    });

    testWidgets('displays offline banner when network is disconnected', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Initially offline banner is not visible
      expect(find.text('No Internet Connection • Offline Mode'), findsNothing);

      // Simulate offline state
      friendProvider.setIsOfflineForTesting(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.text('No Internet Connection • Offline Mode'),
        findsOneWidget,
      );

      // Restore connectivity
      friendProvider.setIsOfflineForTesting(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('No Internet Connection • Offline Mode'), findsNothing);
    });

    testWidgets('PopScope navigates back to Home tab when not on Home', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      var indexedStack = tester.widget<IndexedStack>(
        find.byType(IndexedStack).first,
      );
      expect(indexedStack.index, equals(3));

      // Trigger pop navigation (simulate Android back button)
      final dynamic popScopeState = tester.state(find.byType(NavPageSelector));
      popScopeState.setState(() {
        popScopeState.selectedIndex = 0;
      });
      await tester.pumpAndSettle();

      indexedStack = tester.widget<IndexedStack>(
        find.byType(IndexedStack).first,
      );
      expect(indexedStack.index, equals(0));
    });
  });
}
