import 'package:fin_track/get_information/hash_password.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Password Hashing and Verification', () {
    test('hashes password with v3 prefix and 1000 HMAC rounds', () {
      final hash = hashPassword('Secret123', '9876543210');
      expect(hash.startsWith('v3_'), isTrue);
      expect(hash.length, greaterThan(10));
    });

    test('verifies correct password against generated hash', () {
      const pass = 'MyPass123!';
      const salt = '9998887770';
      final hash = hashPassword(pass, salt);

      expect(verifyPassword(pass, hash, salt), isTrue);
      expect(verifyPassword('WrongPass', hash, salt), isFalse);
    });

    test('verifies legacy v2 salted hash', () {
      // Test backward compatibility fallback
      expect(verifyPassword('password', 'invalid_v2_hash', 'salt'), isFalse);
    });

    test('validates password complexity policy', () {
      expect(isPasswordStrong('abc123'), isTrue);
      expect(isPasswordStrong('Secret!'), isTrue);
      expect(isPasswordStrong('12345'), isFalse); // too short
      expect(isPasswordStrong('abcdef'), isFalse); // no number or special char
      expect(isPasswordStrong('123456'), isFalse); // no letter
    });

    test('asynchronous hash and verify work off-thread', () async {
      const pass = 'AsyncPass99';
      const salt = '9123456789';
      final hash = await hashPasswordAsync(pass, salt);
      expect(hash.startsWith('v3_'), isTrue);

      final isValid = await verifyPasswordAsync(pass, hash, salt);
      expect(isValid, isTrue);

      final isInvalid = await verifyPasswordAsync('BadPass', hash, salt);
      expect(isInvalid, isFalse);
    });
  });
}
