import 'package:fin_track/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('initialization failure shows a usable retry screen', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      BootstrapApp(
        initialize: () async {
          attempts++;
          throw StateError('Offline');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('FinTrack could not start'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('synchronous setup errors also remain retryable', (tester) async {
    await tester.pumpWidget(
      BootstrapApp(
        initialize: () {
          throw StateError('Invalid configuration');
        },
      ),
    );
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('FinTrack could not start'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
