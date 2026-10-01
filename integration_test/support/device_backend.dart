import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> initializeDeviceBackend() async {
  final info = await PackageInfo.fromPlatform();
  if (info.packageName != 'com.vishalnakum.fintrack.qa') {
    throw StateError(
      'Device tests require the separate QA package; got ${info.packageName}.',
    );
  }
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'fake-api-key',
      appId: '1:123456789:android:0000000000000000',
      messagingSenderId: '123456789',
      projectId: 'demo-fintrack-audit',
      databaseURL:
          'http://127.0.0.1:61813/?ns=demo-fintrack-audit-default-rtdb',
      storageBucket: 'demo-fintrack-audit.appspot.com',
    ),
  );
  if (Firebase.app().options.projectId != 'demo-fintrack-audit') {
    throw StateError('Refusing device tests against a non-demo Firebase app.');
  }
  // These phone loopback ports reach laptop emulators through adb reverse.
  await FirebaseAuth.instance.useAuthEmulator(
    '127.0.0.1',
    61812,
    automaticHostMapping: false,
  );
  // Use the already-local default URL, rather than repeatedly mutating the
  // Android SDK's cached RepoInfo via useEmulator on each Pigeon query. The
  // latter opened duplicate persistent repos and triggered an SQLite lock.
  if (Firebase.app().options.databaseURL !=
      'http://127.0.0.1:61813/?ns=demo-fintrack-audit-default-rtdb') {
    throw StateError('Refusing a non-loopback QA database URL.');
  }
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10485760);
}
