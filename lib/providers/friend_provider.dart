import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class FriendProvider extends ChangeNotifier {
  bool _isLoading = false;
  final List<Map<String, dynamic>> _friends = [];

  int _totalGet = 0;
  int _totalGive = 0;

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get friends => _friends;
  int get totalGet => _totalGet;
  int get totalGive => _totalGive;

  /// Fetches all friends and aggregate get/give ledger totals
  Future<void> fetchFriends(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$phoneNumber");
      final event = await ref.once();

      _friends.clear();
      _totalGet = 0;
      _totalGive = 0;

      if (event.snapshot.value != null && event.snapshot.value is Map) {
        final data = event.snapshot.value as Map;
        data.forEach((key, value) {
          if (value is Map) {
            final map = Map<String, dynamic>.from(value);
            _friends.add(map);

            final getVal = int.tryParse(map["total_get"]?.toString() ?? '0') ?? 0;
            final giveVal = int.tryParse(map["total_give"]?.toString() ?? '0') ?? 0;
            _totalGet += getVal;
            _totalGive += giveVal;
          }
        });
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  /// Adds a new friend
  Future<bool> addFriend({
    required String userPhone,
    required String friendName,
    required String friendNumber,
    String note = "",
    required String date,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      await ref.set({
        "friend_name": friendName,
        "friend_number": friendNumber,
        "note": note,
        "date": date,
        "timestamp": ServerValue.timestamp,
        "total_get": "0",
        "total_give": "0",
      });

      await fetchFriends(userPhone);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a friend and all ledger history
  Future<bool> deleteFriend({
    required String userPhone,
    required String friendNumber,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      await ref.remove();
      await fetchFriends(userPhone);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Adds a transaction to a specific friend's ledger
  Future<bool> addFriendTransaction({
    required String userPhone,
    required String friendNumber,
    required String amount,
    required String description,
    required String paymentMode,
    required String date,
    required String categoryType,
  }) async {
    try {
      final recordRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber/Records");
      final key = recordRef.push().key!;
      final parsedAmount = int.tryParse(amount) ?? 0;

      await recordRef.child(key).set({
        "key": key,
        "Amount": amount,
        "Description": description,
        "Payment_Mode": paymentMode,
        "Date": date,
        "Type": categoryType,
        "timestamp": ServerValue.timestamp,
      });

      final friendRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      final snapshot = await friendRef.get();

      int currentGive = int.tryParse(snapshot.child("total_give").value?.toString() ?? "0") ?? 0;
      int currentGet = int.tryParse(snapshot.child("total_get").value?.toString() ?? "0") ?? 0;

      if (categoryType == "Take Money From Friend") {
        currentGive += parsedAmount;
        await friendRef.update({"total_give": currentGive.toString()});
      } else {
        currentGet += parsedAmount;
        await friendRef.update({"total_get": currentGet.toString()});
      }

      await fetchFriends(userPhone);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a specific transaction record from a friend's ledger
  Future<bool> deleteFriendTransaction({
    required String userPhone,
    required String friendNumber,
    required String recordKey,
    required bool isGive,
    required int amount,
  }) async {
    try {
      final recordRef = FirebaseDatabase.instance.ref(
        "Friends/$userPhone/$friendNumber/Records/$recordKey",
      );
      await recordRef.remove();

      final friendRef = FirebaseDatabase.instance.ref("Friends/$userPhone/$friendNumber");
      final snapshot = await friendRef.get();

      int currentGive = int.tryParse(snapshot.child("total_give").value?.toString() ?? "0") ?? 0;
      int currentGet = int.tryParse(snapshot.child("total_get").value?.toString() ?? "0") ?? 0;

      if (isGive) {
        currentGive = (currentGive - amount).clamp(0, 999999999);
        await friendRef.update({"total_give": currentGive.toString()});
      } else {
        currentGet = (currentGet - amount).clamp(0, 999999999);
        await friendRef.update({"total_get": currentGet.toString()});
      }

      await fetchFriends(userPhone);
      return true;
    } catch (_) {
      return false;
    }
  }
}
