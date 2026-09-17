import 'dart:convert';
import 'package:fin_track/get_information/get_user_detail.dart';
import 'package:fin_track/get_information/session_manager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _hasError = false;
  String _name = "User";
  String _email = "";
  String _phoneNumber = "";
  String _address = "";

  static const String _cacheKey = 'cached_user_profile';

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get name => _name;
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String get address => _address;

  Future<void> loadUserSession() async {
    if (_isLoading) return;
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final phone = await SessionManager.getPhoneNumber();
      if (phone != null && phone.isNotEmpty) {
        _phoneNumber = phone;
        final details = await getUserInformation(phone);
        _name = (details["name"] ?? "User").toString();
        _email = (details["email"] ?? "").toString();
        _address = (details["address"] ?? details["Address"] ?? "").toString();

        // Cache profile offline
        try {
          final sp = await SharedPreferences.getInstance();
          await sp.setString(_cacheKey, jsonEncode({
            'name': _name,
            'email': _email,
            'address': _address,
            'phone_number': _phoneNumber,
          }));
        } catch (_) {}
      }
    } catch (_) {
      // Offline fallback: restore from cached profile if available
      try {
        final sp = await SharedPreferences.getInstance();
        final cached = sp.getString(_cacheKey);
        if (cached != null && cached.isNotEmpty) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          _name = (data['name'] ?? _name).toString();
          _email = (data['email'] ?? _email).toString();
          _address = (data['address'] ?? _address).toString();
          _phoneNumber = (data['phone_number'] ?? _phoneNumber).toString();
        } else {
          _hasError = true;
        }
      } catch (_) {
        _hasError = true;
      }
    }

    _isLoading = false;
    notifyListeners();
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
}
