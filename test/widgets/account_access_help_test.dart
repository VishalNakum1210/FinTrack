import 'package:fin_track/authentication/account_access_help.dart';
import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/authentication/registration_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('forgot password explains actual recovery and closes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(find.text('Password recovery'), findsOneWidget);
    expect(
      find.textContaining('cannot receive a password-reset link'),
      findsOneWidget,
    );
    expect(find.textContaining('Never share your password'), findsOneWidget);
    expect(find.textContaining('support@fintrack.app'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'registration discloses recovery limits before creating an account',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: RegistrationPage()));
      await tester.pumpAndSettle();
      expect(find.text(AccountAccessHelp.registrationNotice), findsOneWidget);
    },
  );
}
