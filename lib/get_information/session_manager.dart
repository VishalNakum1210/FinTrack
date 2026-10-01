import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local metadata is a convenience cache. Firebase Auth owns authentication.
class SessionManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _profileKey = 'session_profile_v2';
  static const int sessionExpiryDays = 30;
  static String? get authenticatedUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static String? get authenticatedPhone {
    try {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email == null || !RegExp(r'^\d{10}@fintrack\.app$').hasMatch(email)) {
        return null;
      }
      return email.split('@').first;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _profile() async {
    try {
      final encoded = await _storage.read(key: _profileKey);
      if (encoded == null) return null;
      return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSession({
    required String phoneNumber,
    required String username,
    required String email,
  }) async {
    if (!RegExp(r'^\d{10}$').hasMatch(phoneNumber)) {
      throw ArgumentError('Invalid phone');
    }
    final previous = await _profile();
    final sameUser =
        previous?['phone'] == phoneNumber &&
        previous?['uid'] == authenticatedUid;
    final name = username.trim();
    await _storage.write(
      key: _profileKey,
      value: jsonEncode({
        'phone': phoneNumber,
        'uid': authenticatedUid,
        'name': (name.isEmpty || name == 'User') && sameUser
            ? previous!['name']
            : (name.isEmpty ? 'User' : name),
        'email': email.trim().isEmpty && sameUser
            ? previous!['email']
            : email.trim(),
        'lastActive': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    // Remove obsolete plaintext sessions; never migrate an unverified identity.
    await _clearLegacyPreferences();
  }

  static Future<bool> isSessionValid() async {
    final profile = await _profile();
    if (profile == null ||
        authenticatedPhone == null ||
        profile['phone'] != authenticatedPhone) {
      return false;
    }
    if (profile['uid'] != authenticatedUid) return false;
    final lastActive = profile['lastActive'];
    if (lastActive is! int) {
      await clearSession();
      return false;
    }
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastActive;
    if (elapsed < 0 || elapsed > sessionExpiryDays * 86400000) {
      await clearSession();
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      return false;
    }
    await updateLastActive();
    return true;
  }

  static Future<void> updateLastActive() async {
    final profile = await _profile();
    if (profile == null || authenticatedPhone != profile['phone']) return;
    profile['lastActive'] = DateTime.now().millisecondsSinceEpoch;
    await _storage.write(key: _profileKey, value: jsonEncode(profile));
  }

  static Future<void> _clearLegacyPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final key in [
        'phone_number',
        'username',
        'email',
        'session_last_active',
        'session_signature',
        'cached_user_profile',
        'draft_add_spent_amount',
        'draft_add_spent_desc',
        'pending_feedback',
      ]) {
        await preferences.remove(key);
      }
    } catch (_) {
      /* Legacy cleanup does not weaken secure storage. */
    }
  }

  static Future<void> clearSession() async {
    final profile = await _profile();
    final phone = profile?['phone'];
    if (phone is String && RegExp(r'^\d{10}$').hasMatch(phone)) {
      await _storage.delete(key: 'expense_draft_$phone');
      await _storage.delete(key: 'cached_user_profile_$phone');
      final uid = profile?['uid'];
      if (uid is String && uid.isNotEmpty) {
        await _storage.delete(key: 'cached_user_profile_$uid');
      }
    }
    await _storage.delete(key: _profileKey);
    for (final key in [
      'phone_number',
      'username',
      'email',
      'session_last_active',
      'session_signature',
    ]) {
      await _storage.delete(key: key);
    }
    await _clearLegacyPreferences();
  }

  static Future<String?> getPhoneNumber() async => authenticatedPhone;
  static Future<String?> getUsername() async {
    final profile = await _profile();
    if (profile == null ||
        (authenticatedPhone != null &&
            (profile['phone'] != authenticatedPhone ||
                profile['uid'] != authenticatedUid))) {
      return null;
    }
    return profile['name']?.toString();
  }

  static Future<String?> getEmail() async {
    final profile = await _profile();
    if (profile == null ||
        (authenticatedPhone != null &&
            (profile['phone'] != authenticatedPhone ||
                profile['uid'] != authenticatedUid))) {
      return null;
    }
    return profile['email']?.toString();
  }
}
