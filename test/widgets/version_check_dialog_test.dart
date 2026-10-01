import 'package:fin_track/services/minimum_version_policy.dart';
import 'package:fin_track/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in VersionPolicyFailure.values) {
    testWidgets('$failure has an accurate, retryable, non-dismissible dialog', (
      tester,
    ) async {
      final error = VersionPolicyException(failure);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => VersionCheckFailureDialog(failure: error),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(error.title), findsOneWidget);
      expect(find.text(error.description), findsOneWidget);
      final dialog = tester.element(find.byType(VersionCheckFailureDialog));
      await Navigator.of(dialog).maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(VersionCheckFailureDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(VersionCheckFailureDialog), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(VersionCheckFailureDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
