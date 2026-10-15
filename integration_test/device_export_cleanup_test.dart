import 'package:fin_track/get_information/session_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/device_backend.dart';
import 'support/device_flow.dart';
import 'support/device_recovery_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('resume verified QA fixture for native exports and deletion', (
    tester,
  ) async {
    await initializeDeviceBackend();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('qa_next_phase'), 'recovery');
    final phone = preferences.getString('qa_fixture_phone');
    expect(phone, matches(RegExp(r'^9\d{9}$')));
    expect(SessionManager.authenticatedPhone, phone);
    await startSignedInApp(tester);
    await verifyNativeExportsAndDeletion(
      tester,
      expectedPhone: phone!,
      password: qaChangedPassword,
    );
    await preferences.remove('qa_next_phase');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
