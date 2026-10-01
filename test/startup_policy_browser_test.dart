import 'dart:convert';
import 'package:fin_track/firebase_options.dart';
import 'package:fin_track/services/minimum_version_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/startup_policy_fetch_stub.dart'
    if (dart.library.js_interop) 'support/startup_policy_fetch_web.dart';

const liveStartupCheck = bool.fromEnvironment('FINTRACK_LIVE_STARTUP_CHECK');

// A root-level entry point avoids this Windows Flutter release's nested browser
// test dispatch bug. Ordinary test runs/CI never contact production.
void main() {
  test(
    'Chrome can read the public startup policy without Firebase login',
    () async {
      final endpoint =
          '${DefaultFirebaseOptions.web.databaseURL}/app_config/min_version.json';
      final response = await readStartupPolicy(
        endpoint,
      ).timeout(const Duration(seconds: 20));
      expect(response.status, 200);
      final value = jsonDecode(response.body);
      final minimum = await MinimumVersionPolicy.resolve(
        remote: () async => value == null ? '0.0.0' : value.toString().trim(),
        cached: () async => null,
        cache: (_) async {},
      );
      expect(MinimumVersionPolicy.valid(minimum), isTrue);
    },
    skip: !kIsWeb || !liveStartupCheck,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
