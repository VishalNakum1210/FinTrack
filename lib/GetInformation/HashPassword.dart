import 'dart:convert';
import 'package:crypto/crypto.dart';

const String _appSecretSalt = "FinTrack_Secure_Salt_2026_x#99";

/// Generates a salted SHA-256 hash using a unique salt (e.g. phone number)
/// combined with the application secret salt.
String hashPassword(String password, [String salt = ""]) {
  final combined = "$_appSecretSalt:$salt:$password:$_appSecretSalt";
  final bytes = utf8.encode(combined);
  final digest = sha256.convert(bytes);
  return "v2_${digest.toString()}";
}

/// Verifies whether the entered password matches the stored hash.
/// Supports both modern v2 salted hashes and legacy unsalted SHA-256 hashes.
bool verifyPassword(String enteredPassword, String storedHash, [String salt = ""]) {
  if (storedHash.isEmpty) return false;

  if (storedHash.startsWith("v2_")) {
    return hashPassword(enteredPassword, salt) == storedHash;
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
  final hasDigitOrSpecial = RegExp(r'[0-9!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
  return hasLetter && hasDigitOrSpecial;
}