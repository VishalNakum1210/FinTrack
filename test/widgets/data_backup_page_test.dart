import 'package:fin_track/profile_pages/data_backup_page.dart';
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
    expenseProvider.setRecordsForTesting([
      {
        'key': 'rec-1',
        'Amount': '500',
        'Category': 'Food',
        'Date': '12/09/2026',
        'Payment_Mode': 'Spent Cash',
      }
    ]);

    friendProvider = FriendProvider();
    friendProvider.setFriendsForTesting([
      {
        'friend_name': 'Rahul',
        'friend_number': '9876543210',
        'total_get': '200',
        'total_give': '0',
      }
    ]);

    userProvider = UserProvider();
    userProvider.setUserForTesting(
      name: 'Vishal',
      email: 'vishal@example.com',
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
      child: const MaterialApp(
        home: DataBackupPage(),
      ),
    );
  }

  group('DataBackupPage Widget Tests', () {
    testWidgets('renders header, cloud sync status, and all 3 export options', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Cloud Backup & Export'), findsOneWidget);
      expect(find.text('Cloud Sync Active'), findsOneWidget);
      expect(find.text('Synced Expenses'), findsOneWidget);
      expect(find.text('Friend Ledgers'), findsOneWidget);

      expect(find.text('Full JSON Cloud Backup'), findsOneWidget);
      expect(find.text('Export JSON Backup'), findsOneWidget);

      expect(find.text('Excel / CSV Spreadsheet'), findsOneWidget);
      expect(find.text('Export CSV Sheet'), findsOneWidget);

      expect(find.text('Official PDF Statement'), findsOneWidget);
      expect(find.text('Generate PDF Statement'), findsOneWidget);
    });

    testWidgets('displays offline status when network is disconnected', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Cloud Sync Active'), findsOneWidget);

      friendProvider.setIsOfflineForTesting(true);
      await tester.pump();

      expect(find.text('Cloud Sync Paused (Offline)'), findsOneWidget);
    });

    testWidgets('tapping Export JSON Backup opens action modal and preview dialog', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final jsonButton = find.text('Export JSON Backup');
      await tester.ensureVisible(jsonButton);
      await tester.tap(jsonButton);
      await tester.pumpAndSettle();

      // Action modal should appear
      expect(find.text('JSON Cloud Backup'), findsOneWidget);
      expect(find.text('Google Drive Ready'), findsOneWidget);
      expect(find.text('Save to Google Drive / Share File'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
      expect(find.text('Preview Data'), findsOneWidget);

      // Tap preview data
      await tester.tap(find.text('Preview Data'));
      await tester.pumpAndSettle();

      expect(find.text('JSON Cloud Backup Preview'), findsOneWidget);
      expect(find.text('Copy All'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('tapping Export CSV Sheet opens action modal with CSV options', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final csvButton = find.text('Export CSV Sheet');
      await tester.ensureVisible(csvButton);
      await tester.tap(csvButton);
      await tester.pumpAndSettle();

      // Action modal should appear
      expect(find.text('Excel / CSV Spreadsheet'), findsNWidgets(2));
      expect(find.text('Sheets & Excel Ready'), findsOneWidget);
      expect(find.text('Save to Google Drive / Share CSV'), findsOneWidget);
      expect(find.text('Copy to Clipboard'), findsOneWidget);
    });
  });
}
