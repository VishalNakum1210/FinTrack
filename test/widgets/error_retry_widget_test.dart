import 'package:fin_track/widgets/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorRetryWidget', () {
    testWidgets('renders title and message correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorRetryWidget(
              title: 'Offline Error',
              message: 'Check connection',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Offline Error'), findsOneWidget);
      expect(find.text('Check connection'), findsOneWidget);
      expect(find.text('Tap to Retry'), findsOneWidget);
    });

    testWidgets('triggers onRetry callback when button is tapped', (tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorRetryWidget(
              onRetry: () {
                retryCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap to Retry'));
      await tester.pump();

      expect(retryCalled, isTrue);
    });
  });
}
