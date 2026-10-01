import 'package:fin_track/get_information/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new passwords need length and letters plus numbers or symbols', () {
    expect(isPasswordStrong('abc123'), isFalse);
    expect(isPasswordStrong('abcdefghijklm'), isFalse);
    expect(isPasswordStrong('1234567890123'), isFalse);
    expect(isPasswordStrong('long password 123'), isTrue);
    expect(isPasswordStrong('long-password!'), isTrue);
    expect(isPasswordStrong('a1' * 65), isFalse);
  });
  test('leading and trailing spaces remain part of the password', () {
    const password = '  long password 123  ';
    expect(isPasswordStrong(password), isTrue);
    expect(password.length, 21);
  });
}
