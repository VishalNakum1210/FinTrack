import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

const String _appSecretSalt = String.fromEnvironment('APP_SALT', defaultValue: 'FinTrack_Secure_Salt_2026_x#99');

/// Generates a hardened multi-round salted hash using a phone-number salt
/// and application key derivation rounds.
String hashPassword(String password, [String salt = ""]) {
  // Multi-round key stretching (1000 rounds of HMAC-SHA256)
  final key = utf8.encode("$_appSecretSalt:$salt");
  List<int> currentBytes = utf8.encode(password);

  for (int i = 0; i < 1000; i++) {
    final hmac = Hmac(sha256, key);
    currentBytes = hmac.convert(currentBytes).bytes;
  }

  final digest = sha256.convert(currentBytes);
  return "v3_${digest.toString()}";
}

/// Verifies whether the entered password matches the stored hash.
/// Supports modern v3 multi-round hashes, v2 salted hashes, and legacy unsalted SHA-256 hashes.
bool verifyPassword(String enteredPassword, String storedHash, [String salt = ""]) {
  if (storedHash.isEmpty) return false;

  // Modern v3 multi-round stretched hash
  if (storedHash.startsWith("v3_")) {
    return hashPassword(enteredPassword, salt) == storedHash;
  }

  // Backward compatibility with v2 single-round salted hash
  if (storedHash.startsWith("v2_")) {
    final combined = "$_appSecretSalt:$salt:$enteredPassword:$_appSecretSalt";
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return "v2_${digest.toString()}" == storedHash;
  }

  // Backward compatibility with legacy unsalted SHA-256 hash
  final legacyHash = sha256.convert(utf8.encode(enteredPassword)).toString();
  return legacyHash == storedHash;
}

/// Checks if a password meets the required complexity policy:
/// - Minimum 6 characters
/// - Contains at least one letter (a-z, A-Z)
/// - Contains at least one number (0-9) or special character
bool isPasswordStrong(String password) {
  if (password.length < 6) return false;
  final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
  final hasDigitOrSpecial = RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>_\-+~`=;\\]').hasMatch(password);
  return hasLetter && hasDigitOrSpecial;
}

Future<String> hashPasswordAsync(String password, String salt) {
  return compute(_hashEntry, [password, salt]);
}

Future<bool> verifyPasswordAsync(String entered, String stored, String salt) {
  return compute(_verifyEntry, [entered, stored, salt]);
}

String _hashEntry(List<String> args) => hashPassword(args[0], args[1]);
bool _verifyEntry(List<String> args) => verifyPassword(args[0], args[1], args[2]);
