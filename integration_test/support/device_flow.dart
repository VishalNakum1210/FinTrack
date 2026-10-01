import 'package:fin_track/main.dart' as app;
import 'package:fin_track/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Finder inputWithHint(String hint) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.hintText == hint,
);

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  int seconds = 45,
}) async {
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  if (finder.evaluate().isEmpty) {
    debugPrint(
      'QA wait failed. Visible text: ${tester.allWidgets.whereType<Text>().map((w) => w.data).whereType<String>().join(' | ')}',
    );
    for (final field in tester.allWidgets.whereType<TextField>()) {
      final value = field.controller?.text ?? '';
      debugPrint(
        'QA field ${field.decoration?.hintText}: '
        '${field.obscureText ? "<${value.length} characters>" : value}',
      );
    }
  }
  expect(finder, findsWidgets);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  tester.binding.focusedEditable = null;
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> enter(WidgetTester tester, Finder finder, String value) async {
  await tester.ensureVisible(finder.first);
  // showKeyboard caches this target; after unfocus the same field must request
  // a fresh input connection before the next simulated text event is sent.
  tester.binding.focusedEditable = null;
  await tester.enterText(finder.first, value);
  await tester.pump(const Duration(milliseconds: 200));
  expect(
    tester.widget<TextField>(finder.first).controller?.text == value,
    isTrue,
    reason: 'Input must reach the requested field exactly',
  );
}

Future<void> openPage(WidgetTester tester, Widget page) async {
  final navigator = Navigator.of(tester.element(find.byType(NavPageSelector)));
  navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> startSignedInApp(WidgetTester tester) async {
  await tester.pumpWidget(const app.MyApp());
  await waitFor(tester, find.byType(NavPageSelector));
}

void recordCheck(WidgetTester tester, String name) {
  expect(tester.takeException(), isNull, reason: name);
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.reportData ??= <String, dynamic>{};
  final checks =
      binding.reportData!.putIfAbsent('checks', () => <String>[])
          as List<String>;
  checks.add(name);
  debugPrint('QA CHECK PASSED: $name');
}
