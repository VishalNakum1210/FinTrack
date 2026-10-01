import 'dart:convert';
import 'package:fin_track/main.dart' as app;
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/authentication/registration_page.dart';
import 'package:fin_track/friends_pages/add_friends.dart';
import 'package:fin_track/friends_pages/split_bill_page.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/nav_bar.dart';
import 'package:fin_track/profile_pages/change_password_page.dart';
import 'package:fin_track/profile_pages/feedback_page.dart';
import 'package:fin_track/providers/expense_provider.dart';
import 'package:fin_track/providers/friend_provider.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/services/retry_safe_writer.dart';
import 'package:fin_track/user_pages/add_spent.dart';
import 'package:fin_track/utils/money.dart';
import 'package:fin_track/utils/split_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/device_backend.dart';
import 'support/device_flow.dart';
import 'support/device_recovery_flow.dart';

const qaPassword =
    'Qa1!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
const qaChangedPassword =
    'Qa2!yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy';

Future<Map<String, dynamic>> readMap(String path) async {
  final snapshot = await FirebaseDatabase.instance
      .ref(path)
      .get()
      .timeout(const Duration(seconds: 20));
  return snapshot.exists
      ? Map<String, dynamic>.from(snapshot.value as Map)
      : {};
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated native Android acceptance, money integrity and offline recovery',
    (tester) async {
      await initializeDeviceBackend();
      final qaPreferences = await SharedPreferences.getInstance();
      if (qaPreferences.getString('qa_next_phase') == 'recovery') {
        await verifyProcessRecovery(
          tester,
          expectedPhone: qaPreferences.getString('qa_fixture_phone')!,
          password: qaChangedPassword,
        );
        await qaPreferences.remove('qa_next_phase');
        return;
      }
      await FirebaseAuth.instance.signOut();
      await SessionManager.clearSession();
      final suffix = (DateTime.now().microsecondsSinceEpoch % 1000000000)
          .toString()
          .padLeft(9, '0');
      final phone = '9$suffix';
      final friendPhone = '8$suffix';
      final date =
          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';

      await tester.pumpWidget(const app.MyApp());
      await waitFor(tester, find.byType(LoginPage));
      await tapVisible(tester, find.text('Log In'));
      expect(FirebaseAuth.instance.currentUser, isNull);
      expect(find.byType(LoginPage), findsOneWidget);
      recordCheck(tester, 'startup and empty-login validation');

      await tapVisible(tester, find.text('Sign Up'));
      await waitFor(tester, find.byType(RegistrationPage));
      await enter(tester, inputWithHint('Full Name'), 'QA Emulator User');
      await enter(tester, inputWithHint('10 digit Number'), phone);
      await enter(tester, inputWithHint('Email Address'), 'qa@example.invalid');
      await enter(tester, inputWithHint('Password'), qaPassword);
      await enter(
        tester,
        inputWithHint('Confirm Password'),
        'mismatched-value',
      );
      await tapVisible(tester, find.text('Register & Get Started'));
      expect(FirebaseAuth.instance.currentUser, isNull);
      recordCheck(tester, 'registration rejects mismatched passwords');
      await enter(tester, inputWithHint('Confirm Password'), qaPassword);
      await tapVisible(tester, find.text('Register & Get Started'));
      await waitFor(tester, find.byType(NavPageSelector));
      final profile = await readMap('user_details/$phone');
      expect(profile['owner_uid'], FirebaseAuth.instance.currentUser!.uid);
      expect(await SessionManager.isSessionValid(), isTrue);
      recordCheck(
        tester,
        '80-character registration, UID ownership and native secure session',
      );

      await openPage(tester, const AddSpent());
      await enter(tester, inputWithHint('0.00'), '0.00');
      await enter(
        tester,
        inputWithHint('Add note / description (e.g. Grocery, Lunch)'),
        'QA exact decimal',
      );
      await tapVisible(tester, find.text('Save Transaction'));
      expect(find.byType(AddSpent), findsOneWidget);
      expect(await readMap('Expenses/$phone'), isEmpty);
      recordCheck(tester, 'zero-amount save is rejected');
      await enter(tester, inputWithHint('0.00'), '10.01');
      await tapVisible(tester, find.text('Save Transaction'));
      await waitFor(tester, find.byType(NavPageSelector));
      final expenses = await readMap('Expenses/$phone');
      expect(expenses.length, 1);
      final expenseKey = expenses.keys.single;
      expect(Money.paise((expenses[expenseKey] as Map)['Amount']), 1001);
      recordCheck(tester, 'native form saves exactly 10.01 once');

      await openPage(tester, const AddFriends());
      await enter(tester, inputWithHint("Friend's Name"), 'QA Friend');
      await enter(tester, inputWithHint('10 digit Number'), phone);
      await tapVisible(tester, find.text('Save Friend'));
      expect(find.byType(AddFriends), findsOneWidget);
      expect(await readMap('Friends/$phone'), isEmpty);
      recordCheck(tester, 'adding yourself as a friend is rejected');
      await enter(tester, inputWithHint('10 digit Number'), friendPhone);
      await tapVisible(tester, find.text('Save Friend'));
      await waitFor(tester, find.byType(NavPageSelector));
      expect(
        (await readMap('Friends/$phone')).containsKey(friendPhone),
        isTrue,
      );
      recordCheck(tester, 'native friend creation');

      final context = tester.element(find.byType(NavPageSelector));
      final expenseProvider = context.read<ExpenseProvider>();
      final friends = context.read<FriendProvider>();
      expect(
        await expenseProvider.updateExpense(
          phoneNumber: phone,
          key: expenseKey,
          amount: '12.34',
          category: 'Food',
          paymentMode: 'Spent Cash',
          description: 'QA edited',
          date: date,
        ),
        isTrue,
      );
      expect(
        Money.paise(
          ((await readMap('Expenses/$phone'))[expenseKey] as Map)['Amount'],
        ),
        1234,
      );
      recordCheck(tester, 'native expense edit preserves exact money');

      final splitIntent = RetrySafeWriter.newIntent();
      Future<bool> saveSplit() => friends.atomicSplitBill(
        userPhone: phone,
        friendNumber: friendPhone,
        myShareAmount: '5.01',
        friendShareAmount: '5.00',
        totalAmount: '10.01',
        description: 'QA odd split',
        date: date,
        category: 'Food',
        paymentMode: 'Spent Cash',
        intentId: splitIntent,
      );
      expect(await saveSplit(), isTrue);
      expect(await saveSplit(), isTrue);
      final splitExpenses = await readMap('Expenses/$phone');
      expect(splitExpenses.length, 2);
      final splitEntry = splitExpenses.entries.singleWhere(
        (entry) => (entry.value as Map)['split_id'] != null,
      );
      final records = await readMap('Friends/$phone/$friendPhone/Records');
      expect(records.length, 1);
      expect(
        Money.paise((splitEntry.value as Map)['Amount']) +
            Money.paise((records.values.single as Map)['Amount']),
        1001,
      );
      expect(
        await expenseProvider.updateExpense(
          phoneNumber: phone,
          key: splitEntry.key,
          amount: '9.99',
          category: 'Food',
          paymentMode: 'Spent Cash',
          description: 'forbidden independent edit',
          date: date,
        ),
        isFalse,
      );
      expect(
        await friends.deleteFriend(userPhone: phone, friendNumber: friendPhone),
        isFalse,
      );
      recordCheck(
        tester,
        'atomic odd-paise split, retry deduplication and linked-edit protections',
      );
      expect(
        await expenseProvider.deleteExpense(
          phoneNumber: phone,
          key: splitEntry.key,
        ),
        isTrue,
      );
      expect(await readMap('Friends/$phone/$friendPhone/Records'), isEmpty);
      expect((await readMap('Expenses/$phone')).length, 1);
      recordCheck(tester, 'linked split deletion removes both branches');

      final me = SplitParticipant(phone: phone, name: 'You', isMe: true);
      final friend = SplitParticipant(phone: friendPhone, name: 'QA Friend');
      final bills = [
        GroupExpense(
          id: 'qa-bill',
          title: 'Lunch',
          amount: 10.01,
          category: 'Food',
          date: DateTime.now(),
          payer: me,
          participants: [me, friend],
        ),
      ];
      expect(
        await friends.batchSaveMultiSplit(
          userPhone: phone,
          tripTitle: 'QA cash trip',
          formattedDate: date,
          paymentMode: 'Spent Cash',
          expenses: bills,
          settlements: SplitHelper.calculatePersonSettlements(
            expenses: bills,
            allParticipants: [me, friend],
          ),
          intentId: RetrySafeWriter.newIntent(),
        ),
        isTrue,
      );
      final tripExpenses = await readMap('Expenses/$phone');
      expect(tripExpenses.length, 2);
      expect(
        (tripExpenses.values.singleWhere(
              (value) => (value as Map)['split_id'] != null,
            )
            as Map)['Payment_Mode'],
        'Spent Cash',
      );
      recordCheck(tester, 'native group-trip cash mode and linked ledger save');

      await openPage(
        tester,
        Builder(
          builder: (pageContext) => MediaQuery(
            data: MediaQuery.of(
              pageContext,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: const SplitBillPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      recordCheck(tester, 'single-bill form at 1.8x font scale');
      await tapVisible(tester, find.text('🏖️ Group Trip (Multi-Split)'));
      recordCheck(tester, 'group-trip form at 1.8x font scale');
      Navigator.of(context).pop();
      await tester.pump(const Duration(milliseconds: 500));

      final offlineIntent = RetrySafeWriter.newIntent();
      Future<bool> offlineSave() => expenseProvider.addExpense(
        phoneNumber: phone,
        amount: '0.49',
        description: 'QA offline retry',
        paymentMode: 'Spent Online',
        date: date,
        category: 'Other',
        intentId: offlineIntent,
      );
      await FirebaseDatabase.instance.goOffline();
      expect(await offlineSave(), isFalse);
      expect(RetrySafeWriter.instance.lastWritePending, isTrue);
      expect(await offlineSave(), isFalse);
      await FirebaseDatabase.instance.goOnline();
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      Map<String, dynamic> onlineExpenses = {};
      do {
        await tester.pump(const Duration(milliseconds: 300));
        onlineExpenses = await readMap('Expenses/$phone');
      } while (onlineExpenses.length != 3 && DateTime.now().isBefore(deadline));
      expect(onlineExpenses.length, 3);
      expect(await offlineSave(), isTrue);
      expect((await readMap('Expenses/$phone')).length, 3);
      recordCheck(
        tester,
        'offline timeout, same-intent retry and reconnect create one record',
      );

      for (final tab in ['Passbook', 'Friends', 'Profile', 'Home']) {
        await tapVisible(tester, find.text(tab).last);
        recordCheck(tester, '$tab navigation');
      }
      final exportedRecords = onlineExpenses.entries
          .map((entry) => Map<String, dynamic>.from(entry.value as Map))
          .toList();
      final backup = jsonDecode(
        ExportService.generateJsonBackupString(
          userName: 'QA Emulator User',
          phoneNumber: phone,
          expenses: exportedRecords,
          friends: [await readMap('Friends/$phone/$friendPhone')],
        ),
      );
      expect(backup, isA<Map>());
      expect(
        ExportService.generateCsvString(
          expenses: [
            {...exportedRecords.first, 'Description': ' =1+1'},
          ],
        ),
        contains("' =1+1"),
      );
      recordCheck(
        tester,
        'JSON export serialization and CSV formula neutralization',
      );

      await openPage(tester, const FeedbackPage());
      await enter(tester, find.byType(TextField).first, 'QA emulator feedback');
      await tapVisible(tester, find.text('Submit Feedback'));
      await waitFor(tester, find.text('Thank You!'));
      expect((await readMap('userUpdates/$phone')).length, 1);
      await tapVisible(tester, find.text('Done'));
      recordCheck(tester, 'feedback acknowledged before thank-you');

      await openPage(tester, const ChangePasswordPage());
      await enter(tester, inputWithHint('Enter current password'), qaPassword);
      await enter(
        tester,
        inputWithHint('Enter new password'),
        qaChangedPassword,
      );
      await enter(
        tester,
        inputWithHint('Re-enter new password'),
        qaChangedPassword,
      );
      await tapVisible(tester, find.text('Update Password'));
      await waitFor(tester, find.byType(NavPageSelector));
      await FirebaseAuth.instance.signOut();
      await waitFor(tester, find.byType(LoginPage));
      await enter(tester, inputWithHint('Enter 10 digit number'), phone);
      await enter(tester, inputWithHint('Password'), qaChangedPassword);
      await tapVisible(tester, find.text('Log In'));
      await waitFor(tester, find.byType(NavPageSelector));
      recordCheck(
        tester,
        '80-character password change, sign-out clearing and login',
      );

      await openPage(tester, const AddSpent());
      await enter(tester, inputWithHint('0.00'), '7.89');
      await enter(
        tester,
        inputWithHint('Add note / description (e.g. Grocery, Lunch)'),
        'QA restart draft',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 2));
      recordCheck(
        tester,
        'native secure draft prepared for process-restart test',
      );
      await qaPreferences.setString('qa_fixture_phone', phone);
      await qaPreferences.setString('qa_next_phase', 'recovery');
      IntegrationTestWidgetsFlutterBinding.ensureInitialized()
              .reportData!['fixture_phone'] =
          phone;
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
