import 'package:fin_track/authentication/login_page.dart';
import 'package:fin_track/authentication/registration_page.dart';
import 'package:fin_track/profile_pages/change_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in <String, Widget>{
    'login': const LoginPage(),
    'registration': const RegistrationPage(),
    'password change': const ChangePasswordPage(),
  }.entries) {
    testWidgets(
      '${entry.key} password fields support the advertised 128 characters',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: entry.value));
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        final passwordFields = fields.where((field) => field.obscureText);
        expect(passwordFields, isNotEmpty);
        for (final field in passwordFields) {
          expect(field.maxLength, 128);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final scale in [1.0, 1.8]) {
    testWidgets('registration fits a 274px screen at ${scale}x text scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(274, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const RegistrationPage(),
        ),
      );
      expect(tester.takeException(), isNull);
      final password = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Password',
      );
      await tester.ensureVisible(password);
      await tester.enterText(password, 'Qa1!xxxxxxxxxxxxxxxx');
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Log In'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
    for (final entry in <String, Widget>{
      'login': const LoginPage(),
      'password change': const ChangePasswordPage(),
    }.entries) {
      testWidgets('${entry.key} fits a 274px screen at ${scale}x text scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(274, 640);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: entry.value,
          ),
        );
        expect(tester.takeException(), isNull);
        if (entry.key == 'password change') {
          for (final hint in ['Enter new password', 'Re-enter new password']) {
            final field = find.byWidgetPredicate(
              (widget) =>
                  widget is TextField && widget.decoration?.hintText == hint,
            );
            await tester.ensureVisible(field);
            await tester.enterText(
              field,
              hint == 'Enter new password'
                  ? 'Qa1!xxxxxxxxxxxxxxxx'
                  : 'mismatched-value',
            );
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  }
}
