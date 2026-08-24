import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyPhoneNumber = "phone_number";
  static const String _keyUsername = "username";
  static const String _keyEmail = "email";
  static const String _keyLastActive = "session_last_active";
  static const String _keySessionSignature = "session_signature";
  static const String _sessionSecret = "FinTrack_Session_Secret_2026";

  // Session validity duration: 30 days of inactivity
  static const int sessionExpiryDays = 30;

  /// Generates an HMAC-SHA256 signature for session integrity verification
  static String _generateSignature(String phone, int timestamp) {
    final hmac = Hmac(sha256, utf8.encode(_sessionSecret));
    final digest = hmac.convert(utf8.encode("$phone:$timestamp"));
    return digest.toString();
  }

  /// Creates and saves a secure, signed user session
  static Future<void> saveSession({
    required String phoneNumber,
    required String username,
    required String email,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final signature = _generateSignature(phoneNumber, now);

    await sp.setString(_keyPhoneNumber, phoneNumber);
    await sp.setString(_keyUsername, username);
    await sp.setString(_keyEmail, email);
    await sp.setInt(_keyLastActive, now);
    await sp.setString(_keySessionSignature, signature);
  }

  /// Validates if the local session exists, is cryptographically genuine, and hasn't expired
  static Future<bool> isSessionValid() async {
    final sp = await SharedPreferences.getInstance();
    final phone = sp.getString(_keyPhoneNumber);
    final lastActive = sp.getInt(_keyLastActive);
    final signature = sp.getString(_keySessionSignature);

    if (phone == null || phone.isEmpty || lastActive == null || signature == null) {
      return false;
    }

    // Verify session integrity
    final expectedSignature = _generateSignature(phone, lastActive);
    if (signature != expectedSignature) {
      await clearSession();
      return false;
    }

    // Check expiration (30 days inactivity)
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxInactivityMs = sessionExpiryDays * 24 * 60 * 60 * 1000;
    if (now - lastActive > maxInactivityMs) {
      await clearSession();
      return false;
    }

    // Refresh last active timestamp
    await updateLastActive();
    return true;
  }

  /// Refreshes the last active timestamp and session signature
  static Future<void> updateLastActive() async {
    final sp = await SharedPreferences.getInstance();
    final phone = sp.getString(_keyPhoneNumber);
    if (phone != null && phone.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final signature = _generateSignature(phone, now);
      await sp.setInt(_keyLastActive, now);
      await sp.setString(_keySessionSignature, signature);
    }
  }

  /// Clears all session data on logout or account deletion
  static Future<void> clearSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
  }

  /// Retrieves the authenticated phone number
  static Future<String?> getPhoneNumber() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_keyPhoneNumber);
  }
}
