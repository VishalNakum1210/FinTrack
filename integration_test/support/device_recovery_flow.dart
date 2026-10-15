import 'dart:convert';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:fin_track/nav_bar.dart';
import 'package:fin_track/services/export_service.dart';
import 'package:fin_track/user_pages/add_spent.dart';
import 'package:fin_track/utils/money.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'device_flow.dart';

/// Runs only on the second launch of the same QA APK, after a host force-stop.
Future<void> verifyProcessRecovery(
  WidgetTester tester, {
  required String expectedPhone,
  required String password,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  expect(user, isNotNull);
  expect(SessionManager.authenticatedPhone, expectedPhone);
  expect(await SessionManager.isSessionValid(), isTrue);
  final draft = await const FlutterSecureStorage().read(
    key: 'expense_draft_$expectedPhone',
  );
  expect(draft, isNotNull);
  expect((jsonDecode(draft!) as Map)['owner_uid'], user!.uid);
  await startSignedInApp(tester);
  recordCheck(
    tester,
    'Firebase Auth and encrypted session survive process restart',
  );

  await openPage(tester, const AddSpent());
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (tester.widget<TextField>(inputWithHint('0.00')).controller!.text !=
          '7.89' &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(
    tester.widget<TextField>(inputWithHint('0.00')).controller!.text,
    '7.89',
  );
  expect(
    tester
        .widget<TextField>(
          inputWithHint('Add note / description (e.g. Grocery, Lunch)'),
        )
        .controller!
        .text,
    'QA restart draft',
  );
  await tapVisible(tester, find.text('Save Transaction'));
  await waitFor(tester, find.byType(NavPageSelector));
  final snapshot = await FirebaseDatabase.instance
      .ref('Expenses/$expectedPhone')
      .get();
  final expenses = Map<String, dynamic>.from(snapshot.value as Map);
  expect(expenses.length, 4);
  final recovered =
      expenses.values.singleWhere(
            (entry) => (entry as Map)['Description'] == 'QA restart draft',
          )
          as Map;
  expect(Money.paise(recovered['Amount']), 789);
  await openPage(tester, const AddSpent());
  await tester.pump(const Duration(seconds: 1));
  expect(
    tester.widget<TextField>(inputWithHint('0.00')).controller!.text,
    isEmpty,
  );
  Navigator.of(tester.element(find.byType(AddSpent))).pop();
  await tester.pump(const Duration(milliseconds: 500));
  recordCheck(
    tester,
    'encrypted draft restores after force-stop, saves once and clears',
  );

  await expectLater(
    FirebaseDatabase.instance.ref('Expenses/0000000000').get(),
    throwsA(isA<FirebaseException>()),
  );
  recordCheck(tester, 'native SDK rejects another account ledger read');

  await verifyNativeExportsAndDeletion(
    tester,
    expectedPhone: expectedPhone,
    password: password,
  );
}

Future<void> verifyNativeExportsAndDeletion(
  WidgetTester tester, {
  required String expectedPhone,
  required String password,
}) async {
  expect(SessionManager.authenticatedPhone, expectedPhone);
  final snapshot = await FirebaseDatabase.instance
      .ref('Expenses/$expectedPhone')
      .get();
  final expenses = Map<String, dynamic>.from(snapshot.value as Map);
  expect(expenses.length, 4);
  final recovered = expenses.values.where(
    (record) => (record as Map)['Description'] == 'QA restart draft',
  );
  expect(recovered, hasLength(1));
  expect(Money.paise((recovered.single as Map)['Amount']), 789);

  final records = expenses.values
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList();
  // Cancel each system chooser with Back; never select a recipient or printer.
  // Some devices require manual Back because adb input injection is disabled.
  debugPrint('QA SHARE START: CSV');
  await ExportService.exportCsvSpreadsheet(
    expenses: records,
  ).timeout(const Duration(seconds: 120));
  recordCheck(tester, 'native CSV share chooser opens and can be cancelled');
  debugPrint('QA SHARE START: JSON');
  await ExportService.exportJsonBackup(
    userName: 'QA Emulator User',
    phoneNumber: expectedPhone,
    expenses: records,
    friends: const [],
  ).timeout(const Duration(seconds: 120));
  recordCheck(tester, 'native JSON share chooser opens and can be cancelled');

  final cashSpent = Money.sum(
    records
        .where((record) => record['Payment_Mode'] == 'Spent Cash')
        .map((record) => record['Amount']),
  );
  final onlineSpent = Money.sum(
    records
        .where((record) => record['Payment_Mode'] == 'Spent Online')
        .map((record) => record['Amount']),
  );
  final totalSpent = Money.sum([cashSpent, onlineSpent]);
  debugPrint('QA PRINT START: PDF');
  await ExportService.exportPassbookPdf(
    userName: 'QA Emulator User',
    phoneNumber: expectedPhone,
    records: records,
    totalIncome: 0,
    totalExpense: totalSpent,
    currentBalance: -totalSpent,
    addCash: 0,
    spentCash: cashSpent,
    addOnline: 0,
    spentOnline: onlineSpent,
  ).timeout(const Duration(seconds: 120));
  recordCheck(
    tester,
    'native PDF statement print preview opens and can be cancelled',
  );

  await tapVisible(tester, find.text('Profile').last);
  await tapVisible(tester, find.text('Delete Account').last);
  await waitFor(tester, find.text('Delete Permanently'), seconds: 10);
  await tapVisible(tester, find.text('Delete Permanently'));
  await waitFor(tester, find.text('Confirm Password'));
  await enter(tester, find.byType(TextField).last, password);
  await tapVisible(tester, find.text('Confirm'));
  await waitFor(tester, find.byType(LoginPage));
  expect(FirebaseAuth.instance.currentUser, isNull);
  expect(await SessionManager.isSessionValid(), isFalse);
  expect(
    await const FlutterSecureStorage().read(
      key: 'expense_draft_$expectedPhone',
    ),
    isNull,
  );
  recordCheck(
    tester,
    'native account deletion reauthenticates and clears local identity',
  );
}
