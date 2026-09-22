import 'dart:convert';
import 'package:fin_track/get_information/get_user_detail.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasError = false;
  String _name = _getInitialName();
  String _email = "";
  String _phoneNumber = "";
  String _address = "";

  static const String _cacheKey = 'cached_user_profile';

  UserProvider() {
    _hydrateFromLocalStorage();
  }

  static String _getInitialName() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null &&
          user.displayName != null &&
          user.displayName!.trim().isNotEmpty &&
          user.displayName!.trim() != 'User') {
        return user.displayName!.trim();
      }
    } catch (_) {}
    return "User";
  }

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  String get name {
    if (_name.isNotEmpty && _name != 'User') {
      return _name;
    }
    try {
      final displayName = FirebaseAuth.instance.currentUser?.displayName;
      if (displayName != null &&
          displayName.trim().isNotEmpty &&
          displayName.trim() != 'User') {
        return displayName.trim();
      }
    } catch (_) {}
    return _name;
  }

  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String get address => _address;

  Future<void> _hydrateFromLocalStorage() async {
    bool hasUpdated = false;
    try {
      final sp = await SharedPreferences.getInstance();
      final cached = sp.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        final cName = (data['name'] ?? '').toString().trim();
        if (cName.isNotEmpty && cName != 'User' && cName != _name) {
          _name = cName;
          hasUpdated = true;
        }
        if ((data['email'] ?? '').toString().isNotEmpty && _email.isEmpty) {
          _email = (data['email'] ?? '').toString();
          hasUpdated = true;
        }
        if ((data['address'] ?? '').toString().isNotEmpty && _address.isEmpty) {
          _address = (data['address'] ?? '').toString();
          hasUpdated = true;
        }
        if ((data['phone_number'] ?? '').toString().isNotEmpty && _phoneNumber.isEmpty) {
          _phoneNumber = (data['phone_number'] ?? '').toString();
          hasUpdated = true;
        }
      }
    } catch (_) {}

    if (_name == 'User') {
      try {
        final sessionUsername = await SessionManager.getUsername();
        if (sessionUsername != null &&
            sessionUsername.trim().isNotEmpty &&
            sessionUsername.trim() != 'User') {
          _name = sessionUsername.trim();
          hasUpdated = true;
        }
      } catch (_) {}
    }

    if (_name == 'User') {
      try {
        final displayName = FirebaseAuth.instance.currentUser?.displayName;
        if (displayName != null &&
            displayName.trim().isNotEmpty &&
            displayName.trim() != 'User') {
          _name = displayName.trim();
          hasUpdated = true;
        }
      } catch (_) {}
    }

    if (hasUpdated) {
      notifyListeners();
    }
  }

  Future<void> loadUserSession() async {
    if (_isLoading) return;
    _isLoading = true;
    _hasError = false;

    // Fast local hydration so UI immediately displays cached username
    await _hydrateFromLocalStorage();
    notifyListeners();

    try {
      final phone = _phoneNumber.isNotEmpty
          ? _phoneNumber
          : await SessionManager.getPhoneNumber();

      if (phone != null && phone.isNotEmpty) {
        _phoneNumber = phone;
        final details = await getUserInformation(phone);

        // Flexible key resolution for name
        String? remoteName;
        for (final key in [
          'name',
          'Name',
          'username',
          'userName',
          'fullName',
          'FullName',
          'displayName',
          'DisplayName'
        ]) {
          final val = details[key]?.trim();
          if (val != null && val.isNotEmpty && val != 'User') {
            remoteName = val;
            break;
          }
        }

        if (remoteName != null && remoteName.isNotEmpty) {
          _name = remoteName;
        } else if (_name != 'User') {
          // Self-heal RTDB if remote node is missing name but local profile knows it
          try {
            final ref = FirebaseDatabase.instance.ref("user_details/$phone");
            await ref.update({"name": _name, "phone_number": phone});
          } catch (_) {}
        }

        final remoteEmail = (details["email"] ?? details["Email"] ?? "").trim();
        if (remoteEmail.isNotEmpty) {
          _email = remoteEmail;
        }

        final remoteAddress = (details["address"] ?? details["Address"] ?? "").trim();
        if (remoteAddress.isNotEmpty) {
          _address = remoteAddress;
        }

        // Sync displayName to FirebaseAuth if needed
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null &&
              _name != 'User' &&
              (currentUser.displayName == null || currentUser.displayName != _name)) {
            await currentUser.updateDisplayName(_name);
          }
        } catch (_) {}

        // Persist to SessionManager
        await SessionManager.saveSession(
          phoneNumber: _phoneNumber,
          username: _name,
          email: _email,
        );

        // Update offline cache
        try {
          final sp = await SharedPreferences.getInstance();
          await sp.setString(
            _cacheKey,
            jsonEncode({
              'name': _name,
              'email': _email,
              'address': _address,
              'phone_number': _phoneNumber,
            }),
          );
        } catch (_) {}
      }
    } catch (_) {
      // Offline fallback: restore from cached profile if available
      try {
        final sp = await SharedPreferences.getInstance();
        final cached = sp.getString(_cacheKey);
        if (cached != null && cached.isNotEmpty) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          final cName = (data['name'] ?? '').toString().trim();
          if (cName.isNotEmpty && cName != 'User') {
            _name = cName;
          }
          _email = (data['email'] ?? _email).toString();
          _address = (data['address'] ?? _address).toString();
          _phoneNumber = (data['phone_number'] ?? _phoneNumber).toString();
        } else if (_phoneNumber.isEmpty) {
          _hasError = true;
        }
      } catch (_) {
        if (_phoneNumber.isEmpty) _hasError = true;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates user profile in Firebase and locally
  Future<bool> updateProfile({
    required String name,
    required String email,
    required String address,
  }) async {
    if (_phoneNumber.isEmpty) return false;

    try {
      final ref = FirebaseDatabase.instance.ref("user_details/$_phoneNumber");
      await ref.update({
        "name": name,
        "email": email,
        "address": address,
      });

      _name = name;
      _email = email;
      _address = address;

      // Update FirebaseAuth displayName too
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      } catch (_) {}

      await SessionManager.saveSession(
        phoneNumber: _phoneNumber,
        username: name,
        email: email,
      );

      try {
        final sp = await SharedPreferences.getInstance();
        await sp.setString(_cacheKey, jsonEncode({
          'name': _name,
          'email': _email,
          'address': _address,
          'phone_number': _phoneNumber,
        }));
      } catch (_) {}

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearUser() {
    _name = "User";
    _email = "";
    _phoneNumber = "";
    _address = "";
    _hasError = false;
    SharedPreferences.getInstance().then((sp) {
      sp.remove(_cacheKey);
    }).catchError((_) {});
    notifyListeners();
  }

  @visibleForTesting
  void setUserForTesting({
    required String name,
    required String email,
    required String phoneNumber,
    String address = '',
  }) {
    _name = name;
    _email = email;
    _phoneNumber = phoneNumber;
    _address = address;
    _isLoading = false;
    _hasError = false;
    notifyListeners();
  }
}
