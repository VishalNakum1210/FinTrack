import 'package:fin_track/main.dart' as app;
import 'package:fin_track/authentication/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'support/device_backend.dart';
import 'support/device_flow.dart';
import 'package:firebase_database/firebase_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'isolated Android startup and login validation',
    (tester) async {
      await initializeDeviceBackend();
      final config = await FirebaseDatabase.instance
          .ref('app_config/min_version')
          .get()
          .timeout(const Duration(seconds: 20));
      debugPrint('QA minimum-version connection verified: ${config.exists}');
      await tester.pumpWidget(const app.MyApp());
      await waitFor(tester, find.byType(LoginPage));
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      recordCheck(
        tester,
        'native QA backend connection, startup and login fields',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
