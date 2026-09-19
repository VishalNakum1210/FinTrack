import 'package:fin_track/get_information/session_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionManager username and session handling', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and retrieves phone number, username and email', () async {
      await SessionManager.saveSession(
        phoneNumber: '9876543210',
        username: 'Vishal',
        email: 'vishal@test.com',
      );

      final phone = await SessionManager.getPhoneNumber();
      final username = await SessionManager.getUsername();
      final email = await SessionManager.getEmail();

      expect(phone, equals('9876543210'));
      expect(username, equals('Vishal'));
      expect(email, equals('vishal@test.com'));
    });

    test('preserves existing valid username when subsequent save passes "User"', () async {
      await SessionManager.saveSession(
        phoneNumber: '9876543210',
        username: 'Vishal',
        email: 'vishal@test.com',
      );

      // Subsequent call where username defaults to "User"
      await SessionManager.saveSession(
        phoneNumber: '9876543210',
        username: 'User',
        email: 'vishal@test.com',
      );

      final username = await SessionManager.getUsername();
      expect(username, equals('Vishal'));
    });

    test('clears session on clearSession()', () async {
      await SessionManager.saveSession(
        phoneNumber: '9876543210',
        username: 'Vishal',
        email: 'vishal@test.com',
      );

      await SessionManager.clearSession();

      final phone = await SessionManager.getPhoneNumber();
      final username = await SessionManager.getUsername();

      expect(phone == null || phone.isEmpty, isTrue);
      expect(username == null || username.isEmpty, isTrue);
    });
  });
}
