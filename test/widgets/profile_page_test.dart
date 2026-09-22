import 'package:fin_track/profile_pages/edit_information_page.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/providers/user_provider.dart';
import 'package:fin_track/user_pages/profile.dart';
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
        'Amount': '15000',
        'Category': 'Rent',
        'Date': '01/09/2026',
        'Payment_Mode': 'Spent Online',
      },
      {
        'key': 'rec-2',
        'Amount': '5000',
        'Category': 'Food',
        'Date': '02/09/2026',
        'Payment_Mode': 'Spent Cash',
      },
    ]);

    friendProvider = FriendProvider();
    userProvider = UserProvider();
    userProvider.setUserForTesting(
      name: 'Vishal Nakum',
      email: 'vishal@example.com',
      phoneNumber: '9876543210',
      address: '3 Manned Address, Mariam 3020',
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
        home: ProfilePage(),
      ),
    );
  }

  group('ProfilePage Suite 7 UI Layout Tests', () {
    testWidgets('renders all Suite 7 profile and settings components', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // 1. Header
      expect(find.text("Profile & Settings"), findsOneWidget);

      // 2. User Profile Card
      expect(find.text("Edit Profile"), findsOneWidget);

      // 3. Balanced Summary Cards
      expect(find.text("Total Spent:"), findsOneWidget);
      expect(find.text("Records:"), findsOneWidget);

      // 4. Action Navigation Tiles
      expect(find.text("Personal Information"), findsOneWidget);
      expect(find.text("Security & Password"), findsOneWidget);
      expect(find.text("Financial Reports"), findsOneWidget);
      expect(find.text("Feedback & Support"), findsOneWidget);
      expect(find.text("Log Out"), findsOneWidget);

      // 5. Delete Account Danger Tile
      expect(find.text("Delete Account"), findsOneWidget);
    });

    testWidgets('tapping Log Out opens confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final logoutTile = find.text("Log Out");
      await tester.ensureVisible(logoutTile);
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      expect(find.text("Are you sure you want to log out of FinTrack?"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
    });

    testWidgets('tapping Delete Account opens confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final deleteTile = find.text("Delete Account");
      await tester.ensureVisible(deleteTile);
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();

      expect(find.text("Are you sure you want to permanently delete your account? All expense and friends ledger data will be deleted."), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);

      // Advance cooldown timer to cleanly complete test
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('tapping Edit Profile navigates to EditInformationPage', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final editProfileButton = find.text("Edit Profile");
      await tester.tap(editProfileButton);
      await tester.pumpAndSettle();

      expect(find.byType(EditInformationPage), findsOneWidget);
      expect(find.text("Edit Information"), findsOneWidget);
      expect(find.text("Full Name"), findsOneWidget);
      expect(find.text("Mobile Number"), findsOneWidget);
      expect(find.text("Email"), findsOneWidget);
      expect(find.text("Residential Address"), findsOneWidget);
      expect(find.text("Save Changes"), findsOneWidget);
    });
  });
}
