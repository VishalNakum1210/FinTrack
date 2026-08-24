import 'package:FinTrack/GetInformation/GetUserDetail.dart';
import 'package:FinTrack/GetInformation/SessionManager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _name = "User";
  String _email = "";
  String _phoneNumber = "";
  String _address = "";

  bool get isLoading => _isLoading;
  String get name => _name;
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String get address => _address;

  /// Loads current user information from local session and Firebase
  Future<void> loadUserSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final phone = await SessionManager.getPhoneNumber();
      if (phone != null && phone.isNotEmpty) {
        _phoneNumber = phone;
        final details = await getUserInformation(phone);
        _name = (details["name"] ?? "User").toString();
        _email = (details["email"] ?? "").toString();
        _address = (details["address"] ?? details["Address"] ?? "").toString();
      }
    } catch (_) {}

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

      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resets user state on logout
  void clearUser() {
    _name = "User";
    _email = "";
    _phoneNumber = "";
    _address = "";
    notifyListeners();
  }
}
