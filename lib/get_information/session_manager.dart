import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

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

  /// Creates and saves a secure, encrypted user session
  static Future<void> saveSession({
    required String phoneNumber,
    required String username,
    required String email,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final signature = _generateSignature(phoneNumber, now);

    try {
      await _secureStorage.write(key: _keyPhoneNumber, value: phoneNumber);
      await _secureStorage.write(key: _keyUsername, value: username);
      await _secureStorage.write(key: _keyEmail, value: email);
      await _secureStorage.write(key: _keyLastActive, value: now.toString());
      await _secureStorage.write(key: _keySessionSignature, value: signature);
    } catch (_) {}

    // Keep SharedPreferences in sync for backward compatibility
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyPhoneNumber, phoneNumber);
    await sp.setString(_keyUsername, username);
    await sp.setString(_keyEmail, email);
    await sp.setInt(_keyLastActive, now);
    await sp.setString(_keySessionSignature, signature);
  }

  /// Validates if the local session exists, is cryptographically genuine, and hasn't expired
  static Future<bool> isSessionValid() async {
    String? phone;
    String? lastActiveStr;
    String? signature;

    try {
      phone = await _secureStorage.read(key: _keyPhoneNumber);
      lastActiveStr = await _secureStorage.read(key: _keyLastActive);
      signature = await _secureStorage.read(key: _keySessionSignature);
    } catch (_) {}

    // Fallback migration from SharedPreferences if secure storage is empty
    if (phone == null || lastActiveStr == null || signature == null) {
      final sp = await SharedPreferences.getInstance();
      phone = sp.getString(_keyPhoneNumber);
      final spLastActive = sp.getInt(_keyLastActive);
      signature = sp.getString(_keySessionSignature);
      if (spLastActive != null) {
        lastActiveStr = spLastActive.toString();
      }
      if (phone != null && lastActiveStr != null && signature != null) {
        final name = sp.getString(_keyUsername) ?? "User";
        final email = sp.getString(_keyEmail) ?? "";
        await saveSession(phoneNumber: phone, username: name, email: email);
      }
    }

    if (phone == null || phone.isEmpty || lastActiveStr == null || signature == null) {
      return false;
    }

    final lastActive = int.tryParse(lastActiveStr);
    if (lastActive == null) {
      await clearSession();
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
    const maxInactivityMs = sessionExpiryDays * 24 * 60 * 60 * 1000;
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
    final phone = await getPhoneNumber();
    if (phone != null && phone.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final signature = _generateSignature(phone, now);
      try {
        await _secureStorage.write(key: _keyLastActive, value: now.toString());
        await _secureStorage.write(key: _keySessionSignature, value: signature);
      } catch (_) {}

      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_keyLastActive, now);
      await sp.setString(_keySessionSignature, signature);
    }
  }

  /// Clears all session data on logout or account deletion
  static Future<void> clearSession() async {
    try {
      await _secureStorage.deleteAll();
    } catch (_) {}
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.clear();
    } catch (_) {}
  }

  /// Retrieves the authenticated phone number securely
  static Future<String?> getPhoneNumber() async {
    String? phone;
    try {
      phone = await _secureStorage.read(key: _keyPhoneNumber);
    } catch (_) {}
    if (phone == null || phone.isEmpty) {
      final sp = await SharedPreferences.getInstance();
      phone = sp.getString(_keyPhoneNumber);
    }
    return phone;
  }
}
